import SwiftUI
import Combine

/// Хранилище каталога программ и достижений (обёртка над ядром).
@MainActor
final class CatalogController: ObservableObject {
    @Published private(set) var programs: [Program] = []
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var loadError: String?

    func load() {
        do {
            if let url = CatalogLoader.locate(
                resource: "programs", extension: "json",
                searchPaths: [AppPaths.packageRoot]
            ) {
                programs = try CatalogLoader.loadPrograms(from: url)
            }
            if let url = CatalogLoader.locate(
                resource: "achievements", extension: "json",
                searchPaths: [AppPaths.packageRoot]
            ) {
                achievements = try CatalogLoader.loadAchievements(from: url)
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func program(id: String) -> Program? {
        programs.first { $0.id == id }
    }

    /// Уникальные категории в порядке появления.
    var categoryTitles: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for program in programs {
            let title = program.categoryTitle
            if seen.insert(title).inserted { result.append(title) }
        }
        return result
    }

    func programs(inCategoryTitle title: String) -> [Program] {
        programs.filter { $0.categoryTitle == title }
    }
}

/// Прогресс, аналитика и достижения — обёртки над ядром.
@MainActor
final class ProgressController: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []
    @Published private(set) var unlockedAchievementIDs: Set<Int> = []
    @Published var recentAchievement: Achievement?

    private let store: ProgressStore
    private let analytics: AnalyticsEngine
    private let achievementStore: AchievementStore

    init(fileURL: URL?, analyticsURL: URL?, achievementsURL: URL?) {
        store = ProgressStore(fileURL: fileURL)
        analytics = AnalyticsEngine(fileURL: analyticsURL)
        achievementStore = AchievementStore(fileURL: achievementsURL)
        reload()
    }

    func reload() {
        records = store.records
        unlockedAchievementIDs = achievementStore.unlockedIDs
    }

    var totalSessions: Int { store.totalSessions }
    var totalMinutes: Double { store.totalMinutes }
    var currentStreak: Int { store.currentStreak }
    var distinctPrograms: Int { store.distinctPrograms }
    var todayCount: Int { store.todayCount }
    var sessionHours: Set<Int> { store.sessionHours }

    func count(forProgram id: String) -> Int { store.count(forProgram: id) }

    func minutesByDay(days: Int = 7) -> [(date: Date, minutes: Double)] {
        store.minutesByDay(days: days)
    }

    func addSession(_ record: SessionRecord) {
        store.add(record)
        analytics.track(.sessionComplete, programId: record.programId, value: record.duration)
        reload()
    }

    func trackStart(programId: String) {
        analytics.track(.sessionStart, programId: programId)
    }

    func trackAbort(programId: String, seconds: Double) {
        analytics.track(.sessionAbort, programId: programId, value: seconds)
    }

    func track(_ kind: AnalyticsEvent.Kind, programId: String? = nil, value: Double? = nil) {
        analytics.track(kind, programId: programId, value: value)
    }

    var analyticsSummary: AnalyticsSummary { analytics.summary() }
    var analyticsEvents: [AnalyticsEvent] { analytics.events }

    /// Пересчитывает достижения; новые показываются баннером.
    func refreshAchievements(catalog: [Achievement]) {
        let stats = store.playerStats()
        let fresh = achievementStore.evaluate(catalog: catalog, stats: stats)
        reload()
        if let first = fresh.first {
            recentAchievement = first
        }
    }

    func exportData() -> Data? { store.exportData() }

    func importData(_ data: Data) throws {
        try store.importData(data)
        reload()
    }

    func removeAll() {
        store.removeAll()
        analytics.clear()
        achievementStore.reset()
        reload()
    }
}

/// Лицензия: встроенный файл + промокод разработчика.
@MainActor
final class LicenseController: ObservableObject {

    enum Status: Equatable {
        case free
        case checking
        case full(accessLevelId: String)
        case failed(String)

        var isFull: Bool {
            if case .full = self { return true }
            return false
        }
    }

    @Published private(set) var status: Status = .free
    @Published private(set) var license: License?
    @Published var promoCode: String = ""
    @Published var purchaserId: String = "highwork43@gmail.com"
    @Published var licenseEndpoint: String = ""

    private let manager: LicenseManager
    private let defaults: UserDefaults
    private let statusKey = "pranaria.license.status"
    private let endpointKey = "pranaria.license.endpoint"
    private let purchaserKey = "pranaria.license.purchaser"

    init(licenseURL: URL?, defaults: UserDefaults = .standard) {
        manager = LicenseManager(fileURL: licenseURL)
        self.defaults = defaults
        licenseEndpoint = defaults.string(forKey: endpointKey) ?? ""
        purchaserId = defaults.string(forKey: purchaserKey) ?? "highwork43@gmail.com"
        if let raw = defaults.string(forKey: statusKey), raw.hasPrefix("full:") {
            status = .full(accessLevelId: String(raw.dropFirst("full:".count)))
        }
    }

    var isFullVersion: Bool { status.isFull }

    /// Проверяет встроенную лицензию при запуске.
    func validateEmbeddedLicense() {
        do {
            let license = try manager.validate()
            self.license = license
            status = .full(accessLevelId: license.level)
        } catch {
            license = nil
            if case .full = status { status = .free }
        }
    }

    /// Активация по промокоду через сервер разработчика (если он настроен).
    func activate(promoCode code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = .failed("Введите промокод")
            return
        }
        guard let endpoint = URL(string: licenseEndpoint), !licenseEndpoint.isEmpty else {
            status = .failed("Не задан адрес сервера лицензий (Настройки → Полная версия)")
            return
        }
        status = .checking
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "promoCode": trimmed,
            "purchaserId": purchaserId,
            "platform": "ios",
            "product": "melstudio.breathing.prana.meditate"
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                status = .failed("Некорректный ответ сервера")
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                status = .failed("Сервер ответил кодом \(http.statusCode)")
                return
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let active = (json?["active"] as? Bool) ?? false
            let level = (json?["accessLevelId"] as? String) ?? "pro"
            if active {
                status = .full(accessLevelId: level)
                defaults.set("full:\(level)", forKey: statusKey)
            } else {
                status = .failed("Промокод не найден или не действует")
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func restorePurchase() async {
        await activate(promoCode: "")
    }

    func persistSettings() {
        defaults.set(licenseEndpoint, forKey: endpointKey)
        defaults.set(purchaserId, forKey: purchaserKey)
    }
}
