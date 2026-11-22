import Foundation

/// Достижение — точно так же, как в оригинальном приложении (33 штуки).
public struct Achievement: Codable, Identifiable, Hashable {

    /// Тип условия разблокировки.
    public enum RuleKind: String, Codable, Hashable {
        /// Стать участником сообщества (достигается при первом запуске).
        case member
        /// Выполнить N тренировок.
        case sessionCount
        /// Выполнить N медитаций.
        case meditationCount
        /// N дней подряд.
        case streakDays
        /// Пройти N разных программ.
        case distinctPrograms
        /// Создать свою программу.
        case programCreated
        /// Достичь уровня здоровья N.
        case healthLevel
        /// Пройти все уровни сложности в программе.
        case allDifficulties
        /// Поделиться приложением.
        case shared
        /// Тренировка в указанное время суток.
        case timeOfDay
    }

    /// Условие разблокировки.
    public struct Rule: Codable, Hashable {
        public var kind: RuleKind
        /// Порог для числовых условий.
        public var threshold: Int
        /// Временные отрезки для `timeOfDay`: morning | day | evening | night.
        public var buckets: [String]

        public init(kind: RuleKind, threshold: Int = 0, buckets: [String] = []) {
            self.kind = kind
            self.threshold = threshold
            self.buckets = buckets
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = try container.decode(RuleKind.self, forKey: .kind)
            threshold = try container.decodeIfPresent(Int.self, forKey: .threshold) ?? 0
            buckets = try container.decodeIfPresent([String].self, forKey: .buckets) ?? []
        }
    }

    public var id: Int
    public var name: String
    public var description: String
    /// Имя файла иконки в Content/Images (ach1 … ach33).
    public var icon: String
    public var rule: Rule

    public init(id: Int, name: String, description: String, icon: String, rule: Rule) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.rule = rule
    }
}

/// Сводка состояния игрока для вычисления достижений.
public struct PlayerStats: Codable, Hashable {
    public var totalSessions: Int
    public var totalMeditations: Int
    public var currentStreak: Int
    public var distinctPrograms: Int
    public var createdProgram: Bool
    public var healthLevel: Int
    public var completedAllDifficulties: Bool
    public var sharedApp: Bool
    /// Часы (0–23), в которые выполнялись тренировки.
    public var sessionHours: Set<Int>

    public init(
        totalSessions: Int = 0,
        totalMeditations: Int = 0,
        currentStreak: Int = 0,
        distinctPrograms: Int = 0,
        createdProgram: Bool = false,
        healthLevel: Int = 0,
        completedAllDifficulties: Bool = false,
        sharedApp: Bool = false,
        sessionHours: Set<Int> = []
    ) {
        self.totalSessions = totalSessions
        self.totalMeditations = totalMeditations
        self.currentStreak = currentStreak
        self.distinctPrograms = distinctPrograms
        self.createdProgram = createdProgram
        self.healthLevel = healthLevel
        self.completedAllDifficulties = completedAllDifficulties
        self.sharedApp = sharedApp
        self.sessionHours = sessionHours
    }

    /// Время суток, в которые уже была тренировка.
    public var coveredBuckets: Set<String> {
        var result = Set<String>()
        for hour in sessionHours {
            switch hour {
            case 5...11: result.insert("morning")
            case 12...17: result.insert("day")
            case 18...22: result.insert("evening")
            default: result.insert("night")
            }
        }
        return result
    }
}
