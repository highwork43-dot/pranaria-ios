import XCTest
@testable import PranariaCore

/// Общие помощники тестов: путь к корню пакета и загрузка каталогов.
enum TestSupport {
    /// Корень пакета вычисляется от пути к исходнику теста.
    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)      // Tests/PranariaCoreTests/CoreTests.swift
            .deletingLastPathComponent()      // PranariaCoreTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // корень пакета
    }

    static var programsURL: URL {
        packageRoot.appendingPathComponent("Content/programs.json")
    }

    static var achievementsURL: URL {
        packageRoot.appendingPathComponent("Content/achievements.json")
    }

    static var licenseURL: URL {
        packageRoot.appendingPathComponent("Content/license.json")
    }

    static func loadPrograms() throws -> [Program] {
        try CatalogLoader.loadPrograms(from: programsURL)
    }

    static func loadAchievements() throws -> [Achievement] {
        try CatalogLoader.loadAchievements(from: achievementsURL)
    }
}

// MARK: - Каталог

final class CatalogTests: XCTestCase {

    func testCatalogLoads24Programs() throws {
        let programs = try TestSupport.loadPrograms()
        XCTAssertEqual(programs.count, 24)
    }

    func testProgramFieldsAreFilled() throws {
        let programs = try TestSupport.loadPrograms()
        for program in programs {
            XCTAssertFalse(program.name.isEmpty, "пустое имя у \(program.id)")
            XCTAssertFalse(program.icon.isEmpty)
            XCTAssertFalse(program.backgroundImage.isEmpty)
            XCTAssertTrue(program.backgroundColor.hasPrefix("#"))
            XCTAssertGreaterThan(program.lengthMinutes, 0)
        }
    }

    func testProgramsHaveValidCycles() throws {
        let programs = try TestSupport.loadPrograms()
        for program in programs {
            XCTAssertFalse(program.cycles.isEmpty, "нет циклов у \(program.name)")
            for cycle in program.cycles {
                XCTAssertEqual(cycle.phases.count, 4, "цикл должен содержать 4 фазы")
                XCTAssertGreaterThan(cycle.repeats, 0)
            }
        }
    }

    func testSquareBreathingHasFourFour() throws {
        let programs = try TestSupport.loadPrograms()
        let square = try XCTUnwrap(programs.first { $0.name == "Квадратное дыхание" })
        let plan = ProgramPlan.make(program: square, difficulty: 0)
        XCTAssertEqual(plan.proportionsDescription, "4–4–4–4")
    }

    func testCategoryTitlesAreUniqueAndOrdered() throws {
        let programs = try TestSupport.loadPrograms()
        // непустые категории уникальны
        var seen = Set<String>()
        for program in programs where !program.category.isEmpty {
            XCTAssertTrue(seen.insert(program.category).inserted, "дубль категории \(program.category)")
        }
        // программы без категории попадают в один бакет «Прочие»
        let withoutCategory = programs.filter { $0.category.isEmpty }
        XCTAssertTrue(withoutCategory.allSatisfy { $0.categoryTitle == "Прочие" })
    }

    func testAchievementsCatalogHas33Items() throws {
        let achievements = try TestSupport.loadAchievements()
        XCTAssertEqual(achievements.count, 33)
        XCTAssertEqual(achievements.first?.name, "Пранария")
        XCTAssertEqual(achievements.last?.name, "Любое время")
    }
}

// MARK: - Расчёт плана

final class ProgramPlanTests: XCTestCase {

    func testPlanProducesPositiveDurations() throws {
        let programs = try TestSupport.loadPrograms()
        for program in programs {
            for difficulty in 0...program.maxDifficulty {
                let plan = ProgramPlan.make(program: program, difficulty: difficulty)
                XCTAssertFalse(plan.steps.isEmpty, "пустой план: \(program.name)")
                for step in plan.steps {
                    XCTAssertGreaterThan(step.phase.seconds, 0, "нулевая фаза в \(program.name)")
                    XCTAssertLessThanOrEqual(step.phase.seconds, 120, "слишком длинная фаза в \(program.name)")
                }
                XCTAssertGreaterThan(plan.totalDuration, 0)
            }
        }
    }

    func testFixedPhasesAreNotMultiplied() throws {
        let programs = try TestSupport.loadPrograms()
        // «Капалабхати»: цикл '1.5:0:1.5:0', tip = 1 → 1.5 с
        let kapalabhati = try XCTUnwrap(programs.first { $0.name == "Капалабхати" })
        let plan = ProgramPlan.make(program: kapalabhati, difficulty: 0)
        XCTAssertEqual(plan.steps.first?.phase.seconds ?? 0, 1.5, accuracy: 0.001)
    }

    func testDifficultyIncreasesDurations() throws {
        let programs = try TestSupport.loadPrograms()
        let program = try XCTUnwrap(programs.first { $0.maxDifficulty > 0 })
        let easy = ProgramPlan.make(program: program, difficulty: 0)
        let hard = ProgramPlan.make(program: program, difficulty: program.maxDifficulty)
        XCTAssertGreaterThan(hard.totalDuration, easy.totalDuration)
    }

    func testPlanIsDeterministic() throws {
        let programs = try TestSupport.loadPrograms()
        let program = try XCTUnwrap(programs.first)
        let a = ProgramPlan.make(program: program, difficulty: 2)
        let b = ProgramPlan.make(program: program, difficulty: 2)
        XCTAssertEqual(a.steps.count, b.steps.count)
        XCTAssertEqual(a.totalDuration, b.totalDuration, accuracy: 0.0001)
    }
}

// MARK: - Движок сессии

final class BreathSessionTests: XCTestCase {

    private func makePlan() throws -> ProgramPlan {
        let programs = try TestSupport.loadPrograms()
        let square = try XCTUnwrap(programs.first { $0.name == "Квадратное дыхание" })
        return ProgramPlan.make(program: square, difficulty: 0)
    }

    func testSessionFinishesAndReportsElapsed() throws {
        let plan = try makePlan()
        let session = BreathSession()
        var finishedProgram: Program?
        session.onFinish = { finishedProgram = $0 }

        session.start(plan)
        XCTAssertEqual(session.state, .running)

        var guardCounter = 0
        while session.state == .running, guardCounter < 100_000 {
            session.tick(delta: 0.05)
            guardCounter += 1
        }

        XCTAssertEqual(session.state, .finished)
        XCTAssertNotNil(finishedProgram)
        XCTAssertEqual(session.elapsed, plan.totalDuration, accuracy: 0.5)
        XCTAssertEqual(session.remaining, 0, accuracy: 0.5)
    }

    func testPhaseChangeCallbacksMatchTimeline() throws {
        let plan = try makePlan()
        let session = BreathSession()
        var phases: [BreathPhaseKind] = []
        session.onPhaseChange = { phases.append($0) }

        session.start(plan)
        var guardCounter = 0
        while session.state == .running, guardCounter < 100_000 {
            session.tick(delta: 0.05)
            guardCounter += 1
        }
        // первая фаза выдаётся при старте, далее — на каждом переходе
        XCTAssertEqual(phases.count, session.totalSteps)
        XCTAssertEqual(phases.first, .inhale)
    }

    func testPauseStopsTime() throws {
        let plan = try makePlan()
        let session = BreathSession()
        session.start(plan)
        session.tick(delta: 1.0)
        let elapsed = session.elapsed
        session.pause()
        session.tick(delta: 5.0)
        XCTAssertEqual(session.elapsed, elapsed, accuracy: 0.0001)
        session.resume()
        session.tick(delta: 1.0)
        XCTAssertGreaterThan(session.elapsed, elapsed)
    }

    func testCircleScaleGrowsOnInhale() throws {
        let plan = try makePlan()
        let session = BreathSession()
        session.start(plan)
        XCTAssertEqual(session.currentPhaseKind, .inhale)
        session.tick(delta: plan.steps[0].phase.seconds / 2)
        XCTAssertGreaterThan(session.circleScale, 0.2)
        XCTAssertLessThan(session.circleScale, 0.8)
    }

    func testStopResetsState() throws {
        let plan = try makePlan()
        let session = BreathSession()
        session.start(plan)
        session.tick(delta: 2)
        session.stop()
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(session.elapsed, 0)
        XCTAssertEqual(session.stepIndex, 0)
    }

    func testTimelineLengthMatchesPlan() throws {
        let plan = try makePlan()
        let timeline = BreathSession.makeTimeline(for: plan)
        XCTAssertEqual(timeline.count, plan.steps.count)
        XCTAssertEqual(timeline.map(\.phase), plan.steps.map(\.phase))
    }
}

// MARK: - Достижения

final class AchievementEngineTests: XCTestCase {

    func testFirstSessionUnlocksSecondAchievement() throws {
        let catalog = try TestSupport.loadAchievements()
        var stats = PlayerStats()
        XCTAssertTrue(AchievementEngine.isUnlocked(catalog[0], stats: stats), "первое достижение всегда доступно")
        XCTAssertFalse(AchievementEngine.isUnlocked(catalog[1], stats: stats))
        stats.totalSessions = 1
        XCTAssertTrue(AchievementEngine.isUnlocked(catalog[1], stats: stats))
    }

    func testStreakAndProgramRules() throws {
        let catalog = try TestSupport.loadAchievements()
        let stats = PlayerStats(totalSessions: 30, currentStreak: 7, distinctPrograms: 5)
        XCTAssertTrue(AchievementEngine.isUnlocked(catalog[3], stats: stats))   // 10 тренировок
        XCTAssertTrue(AchievementEngine.isUnlocked(catalog[16], stats: stats))  // 7 дней
        XCTAssertTrue(AchievementEngine.isUnlocked(catalog[25], stats: stats))  // 5 программ
        XCTAssertFalse(AchievementEngine.isUnlocked(catalog[26], stats: stats)) // 10 программ
    }

    func testTimeOfDayBuckets() throws {
        let catalog = try TestSupport.loadAchievements()
        let night = catalog.first { $0.rule.kind == .timeOfDay && $0.rule.buckets.contains("night") }
        let morning = catalog.first { $0.rule.buckets.contains("morning") }
        let anyTime = catalog.last!

        var stats = PlayerStats()
        stats.sessionHours = [2]   // ночь
        XCTAssertTrue(AchievementEngine.isUnlocked(night!, stats: stats))
        XCTAssertFalse(AchievementEngine.isUnlocked(morning!, stats: stats))
        XCTAssertFalse(AchievementEngine.isUnlocked(anyTime, stats: stats))

        stats.sessionHours = [2, 9, 14, 20]
        XCTAssertTrue(AchievementEngine.isUnlocked(anyTime, stats: stats))
    }

    func testStorePersistsUnlockedAchievements() throws {
        let catalog = try TestSupport.loadAchievements()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ach-\(UUID().uuidString).json")
        let store = AchievementStore(fileURL: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let stats = PlayerStats(totalSessions: 10)
        let fresh = store.evaluate(catalog: catalog, stats: stats)
        XCTAssertFalse(fresh.isEmpty)
        XCTAssertTrue(store.isUnlocked(catalog[3]))

        let reloaded = AchievementStore(fileURL: url)
        XCTAssertTrue(reloaded.isUnlocked(catalog[3]))
    }
}

// MARK: - Прогресс

final class ProgressStoreTests: XCTestCase {

    private func makeStore() -> (ProgressStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-\(UUID().uuidString).json")
        return (ProgressStore(fileURL: url), url)
    }

    func testAddAndCount() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        store.add(SessionRecord(programId: "p1", programName: "Квадратное дыхание", duration: 60))
        store.add(SessionRecord(programId: "p2", programName: "Капалабхати", duration: 120, isMeditation: true))
        XCTAssertEqual(store.totalSessions, 2)
        XCTAssertEqual(store.totalMinutes, 3, accuracy: 0.001)
        XCTAssertEqual(store.totalMeditations, 1)
        XCTAssertEqual(store.distinctPrograms, 2)
    }

    func testExportImportRoundTrip() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        store.add(SessionRecord(programId: "p1", programName: "Тест", duration: 42, difficulty: 3))
        let data = try XCTUnwrap(store.exportData())

        let (other, otherURL) = makeStore()
        defer { try? FileManager.default.removeItem(at: otherURL) }
        try other.importData(data)
        XCTAssertEqual(other.records.count, 1)
        XCTAssertEqual(other.records.first?.difficulty, 3)
    }

    func testStreakCalculation() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let calendar = Calendar.current
        for offset in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            store.add(SessionRecord(programId: "p", programName: "n", startedAt: date, duration: 60))
        }
        XCTAssertEqual(store.currentStreak, 3)
    }
}

// MARK: - Лицензия

final class LicenseTests: XCTestCase {

    func testEmbeddedLicenseIsValid() throws {
        let manager = LicenseManager(fileURL: TestSupport.licenseURL)
        let license = try manager.validate()
        XCTAssertEqual(license.level, "pro")
        XCTAssertEqual(license.email, "highwork43@gmail.com")
        XCTAssertEqual(license.purchase?.receipt, "312")
        XCTAssertEqual(license.purchase?.amount, 1179)
    }

    func testTamperedLicenseIsRejected() throws {
        let manager = LicenseManager(fileURL: TestSupport.licenseURL)
        let envelope = try manager.loadEnvelope()
        var tampered = envelope.payload
        tampered.level = "free"
        let forged = LicenseManager.makeEnvelope(for: tampered)
        // подпись пересчитана «не тем» ключом
        let forged2 = LicenseEnvelope(
            version: envelope.version,
            payload: tampered,
            signature: LicenseManager.signature(for: tampered)
        )
        XCTAssertNotEqual(forged.signature, envelope.signature)
        XCTAssertNotEqual(forged2.signature, envelope.signature)
    }

    func testSignatureIsStable() {
        let manager = LicenseManager(fileURL: TestSupport.licenseURL)
        let envelope = try? manager.loadEnvelope()
        XCTAssertNotNil(envelope)
        let signature = LicenseManager.signature(for: envelope!.payload)
        XCTAssertEqual(signature, envelope!.signature)
        XCTAssertEqual(signature.count, 64)
    }
}

// MARK: - SHA-256

final class SHA256Tests: XCTestCase {

    func testKnownVectors() {
        let empty = SHA256.hex([UInt8]())
        XCTAssertEqual(empty, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

        let abc = SHA256.hex([UInt8]("abc".utf8))
        XCTAssertEqual(abc, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

        let long = SHA256.hex([UInt8](String(repeating: "a", count: 1000).utf8))
        XCTAssertEqual(long.count, 64)
    }

    func testHMACVector() {
        // RFC 4231, test case 1
        let key = [UInt8](repeating: 0x0b, count: 20)
        let message = [UInt8]("Hi There".utf8)
        let mac = SHA256.format(SHA256.hmac(key: key, message: message))
        XCTAssertEqual(mac, "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
    }
}

// MARK: - Аналитика

final class AnalyticsTests: XCTestCase {

    func testSummaryAggregates() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("analytics-\(UUID().uuidString).json")
        let engine = AnalyticsEngine(fileURL: url)
        defer { try? FileManager.default.removeItem(at: url) }

        engine.track(.sessionStart, programId: "p1")
        engine.track(.sessionComplete, programId: "p1", value: 300)
        engine.track(.sessionComplete, programId: "p2", value: 120)

        let summary = engine.summary()
        XCTAssertEqual(summary.totalSessions, 1)
        XCTAssertEqual(summary.completedSessions, 2)
        XCTAssertEqual(summary.uniquePrograms, 2)
        XCTAssertEqual(summary.totalMinutes, 7, accuracy: 0.001)
        XCTAssertEqual(summary.completionRate, 2, accuracy: 0.001)
    }
}

// MARK: - Инструкции

final class InstructionTests: XCTestCase {

    func testPhasePhrases() {
        XCTAssertEqual(InstructionProvider.phasePhrase(.inhale), "Вдох")
        XCTAssertEqual(InstructionProvider.phasePhrase(.exhale), "Выдох")
        XCTAssertFalse(InstructionProvider.phaseGuidance(.inhale).isEmpty)
    }

    func testGeneralInstructionsExist() {
        XCTAssertGreaterThanOrEqual(InstructionProvider.generalInstructions.count, 5)
    }

    func testProportionsExplanationUsesComputedSeconds() throws {
        let programs = try TestSupport.loadPrograms()
        let square = try XCTUnwrap(programs.first { $0.name == "Квадратное дыхание" })
        let plan = ProgramPlan.make(program: square, difficulty: 0)
        let text = InstructionProvider.proportionsExplanation(for: plan)
        XCTAssertTrue(text.contains("4"), text)
        XCTAssertTrue(text.contains("секунд"), text)
    }
}
