import Foundation

/// Запись о завершённой тренировке.
public struct SessionRecord: Codable, Identifiable, Hashable {
    public var id: UUID
    public var programId: String
    public var programName: String
    public var startedAt: Date
    public var duration: Double
    public var completedRepeats: Int
    /// Уровень сложности, на котором выполнялась тренировка.
    public var difficulty: Int
    public var isMeditation: Bool

    public init(
        id: UUID = UUID(),
        programId: String,
        programName: String,
        startedAt: Date = Date(),
        duration: Double,
        completedRepeats: Int = 0,
        difficulty: Int = 0,
        isMeditation: Bool = false
    ) {
        self.id = id
        self.programId = programId
        self.programName = programName
        self.startedAt = startedAt
        self.duration = duration
        self.completedRepeats = completedRepeats
        self.difficulty = difficulty
        self.isMeditation = isMeditation
    }
}

/// Хранилище прогресса: завершённые сессии, серия дней, суммарное время.
///
/// Данные лежат в Application Support и могут экспортироваться/импортироваться
/// как JSON (в оригинале это «Настройки → Резервная копия»).
public final class ProgressStore {

    public private(set) var records: [SessionRecord] = []

    private let fileURL: URL?
    private let calendar: Calendar

    public init(fileURL: URL?, calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.calendar = calendar
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SessionRecord].self, from: data) {
            records = decoded
        }
    }

    private func save() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Mutations

    public func add(_ record: SessionRecord) {
        records.insert(record, at: 0)
        save()
    }

    public func removeAll() {
        records.removeAll()
        save()
    }

    // MARK: - Export / Import

    public func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(records)
    }

    public func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([SessionRecord].self, from: data)
        records = decoded
        save()
    }

    // MARK: - Statistics

    public var totalSessions: Int { records.count }

    public var totalMinutes: Double {
        records.reduce(0) { $0 + $1.duration } / 60.0
    }

    public var totalMeditations: Int {
        records.filter(\.isMeditation).count
    }

    public var todayCount: Int {
        records.filter { calendar.isDateInToday($0.startedAt) }.count
    }

    /// Серия дней подряд, в которые была хотя бы одна тренировка.
    public var currentStreak: Int {
        guard let last = records.map(\.startedAt).max() else { return 0 }
        var streak = 0
        var day = calendar.startOfDay(for: last)
        let days = Set(records.map { calendar.startOfDay(for: $0.startedAt) })
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Часы (0–23), в которые выполнялись тренировки.
    public var sessionHours: Set<Int> {
        Set(records.map { calendar.component(.hour, from: $0.startedAt) })
    }

    public var distinctPrograms: Int {
        Set(records.map(\.programId)).count
    }

    /// Распределение по дням за последние `days` суток.
    public func minutesByDay(days: Int = 7) -> [(date: Date, minutes: Double)] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset -> (Date, Double)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = records
                .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
                .reduce(0) { $0 + $1.duration } / 60.0
            return (date, minutes)
        }
    }

    public func count(forProgram id: String) -> Int {
        records.filter { $0.programId == id }.count
    }

    /// Все ли уровни сложности программы пройдены (для достижения №24).
    public func completedAllDifficulties(for programId: String, maxDifficulty: Int) -> Bool {
        let levels = Set(
            records
                .filter { $0.programId == programId }
                .map { $0.difficulty }
        )
        return levels.count >= maxDifficulty + 1
    }

    /// Сводка для системы достижений.
    public func playerStats(
        healthLevel: Int = 0,
        createdProgram: Bool = false,
        sharedApp: Bool = false
    ) -> PlayerStats {
        PlayerStats(
            totalSessions: totalSessions,
            totalMeditations: totalMeditations,
            currentStreak: currentStreak,
            distinctPrograms: distinctPrograms,
            createdProgram: createdProgram,
            healthLevel: healthLevel,
            completedAllDifficulties: false,
            sharedApp: sharedApp,
            sessionHours: sessionHours
        )
    }
}
