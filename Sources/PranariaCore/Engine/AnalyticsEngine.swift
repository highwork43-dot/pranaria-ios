import Foundation

/// Событие аналитики.
///
/// События хранятся локально на устройстве: ничего не уходит в интернет,
/// персональные данные никуда не передаются.
public struct AnalyticsEvent: Codable, Identifiable, Hashable {

    public enum Kind: String, Codable, Hashable {
        case appLaunch
        case programOpen
        case sessionStart
        case sessionComplete
        case sessionAbort
        case phaseCompleted
        case difficultyChanged
        case achievementUnlocked
        case licenseActivated
        case settingsChanged
        case appShared
    }

    public var id: UUID
    public var kind: Kind
    public var timestamp: Date
    /// Идентификатор программы (для событий, связанных с тренировкой).
    public var programId: String?
    /// Произвольное числовое значение (длительность, счётчик и т. п.).
    public var value: Double?
    /// Дополнительные строковые метки.
    public var properties: [String: String]

    public init(
        id: UUID = UUID(),
        kind: Kind,
        timestamp: Date = Date(),
        programId: String? = nil,
        value: Double? = nil,
        properties: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.programId = programId
        self.value = value
        self.properties = properties
    }
}

/// Агрегаты по событиям — используются экраном аналитики.
public struct AnalyticsSummary {
    public var totalSessions: Int = 0
    public var completedSessions: Int = 0
    public var abortedSessions: Int = 0
    public var totalMinutes: Double = 0
    public var averageSessionMinutes: Double = 0
    public var uniquePrograms: Int = 0
    public var sessionsByDay: [(date: Date, count: Int)] = []
    public var minutesByDay: [(date: Date, minutes: Double)] = []
    public var timeOfDayDistribution: [String: Int] = [:]
    public var topPrograms: [(programId: String, count: Int)] = []
    public var completionRate: Double = 0
}

/// Локальный сборщик аналитики.
public final class AnalyticsEngine {

    private let fileURL: URL?
    private let calendar: Calendar
    private(set) var events: [AnalyticsEvent]

    public init(fileURL: URL?, calendar: Calendar = .current, limit: Int = 5000) {
        self.fileURL = fileURL
        self.calendar = calendar
        self.events = []
        load(limit: limit)
    }

    public func track(
        _ kind: AnalyticsEvent.Kind,
        programId: String? = nil,
        value: Double? = nil,
        properties: [String: String] = [:]
    ) {
        events.append(
            AnalyticsEvent(kind: kind, programId: programId, value: value, properties: properties)
        )
        save()
    }

    public func clear() {
        events.removeAll()
        save()
    }

    // MARK: - Агрегация

    public func summary(days: Int = 30) -> AnalyticsSummary {
        var summary = AnalyticsSummary()

        let sessions = events.filter { $0.kind == .sessionComplete }
        summary.totalSessions = events.filter { $0.kind == .sessionStart }.count
        summary.completedSessions = sessions.count
        summary.abortedSessions = events.filter { $0.kind == .sessionAbort }.count
        summary.totalMinutes = sessions.reduce(0) { $0 + ($1.value ?? 0) } / 60.0
        summary.averageSessionMinutes = sessions.isEmpty ? 0 : summary.totalMinutes / Double(sessions.count)
        summary.completionRate = summary.totalSessions == 0
            ? 0
            : Double(summary.completedSessions) / Double(summary.totalSessions)

        var programIDs = Set<String>()
        var programCounts: [String: Int] = [:]
        var hourCounts: [String: Int] = [:]
        for event in sessions {
            if let id = event.programId {
                programIDs.insert(id)
                programCounts[id, default: 0] += 1
            }
            let hour = calendar.component(.hour, from: event.timestamp)
            let bucket: String
            switch hour {
            case 5...11: bucket = "morning"
            case 12...17: bucket = "day"
            case 18...22: bucket = "evening"
            default: bucket = "night"
            }
            hourCounts[bucket, default: 0] += 1
        }
        summary.uniquePrograms = programIDs.count
        summary.timeOfDayDistribution = hourCounts
        summary.topPrograms = programCounts
            .map { (programId: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        let today = calendar.startOfDay(for: Date())
        summary.sessionsByDay = (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.count
            return (date, count)
        }
        summary.minutesByDay = (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = sessions
                .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
                .reduce(0) { $0 + ($1.value ?? 0) } / 60.0
            return (date, minutes)
        }
        return summary
    }

    // MARK: - Хранение

    private func load(limit: Int) {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([AnalyticsEvent].self, from: data) {
            events = Array(decoded.suffix(limit))
        }
    }

    private func save() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
