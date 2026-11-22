import Foundation

/// Вычисляет, какие достижения выполнены, по статистике игрока.
public enum AchievementEngine {

    /// Проверяет условие конкретного достижения.
    public static func isUnlocked(_ achievement: Achievement, stats: PlayerStats) -> Bool {
        switch achievement.rule.kind {
        case .member:
            return true
        case .sessionCount:
            return stats.totalSessions >= achievement.rule.threshold
        case .meditationCount:
            return stats.totalMeditations >= achievement.rule.threshold
        case .streakDays:
            return stats.currentStreak >= achievement.rule.threshold
        case .distinctPrograms:
            return stats.distinctPrograms >= achievement.rule.threshold
        case .programCreated:
            return stats.createdProgram
        case .healthLevel:
            return stats.healthLevel >= achievement.rule.threshold
        case .allDifficulties:
            return stats.completedAllDifficulties
        case .shared:
            return stats.sharedApp
        case .timeOfDay:
            let covered = stats.coveredBuckets
            if achievement.rule.buckets.isEmpty {
                // «Любое время» — нужны все четыре отрезка суток.
                return covered.count >= 4
            }
            return achievement.rule.buckets.allSatisfy { covered.contains($0) }
        }
    }

    /// Список разблокированных достижений.
    public static func unlocked(catalog: [Achievement], stats: PlayerStats) -> [Achievement] {
        catalog.filter { isUnlocked($0, stats: stats) }
    }

    /// Новые достижения относительно уже полученных.
    public static func newlyUnlocked(
        catalog: [Achievement],
        stats: PlayerStats,
        known: Set<Int>
    ) -> [Achievement] {
        unlocked(catalog: catalog, stats: stats).filter { !known.contains($0.id) }
    }
}

/// Хранилище полученных достижений.
public final class AchievementStore {

    private let fileURL: URL?
    private var storedIDs: Set<Int>

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        storedIDs = Set<Int>()
        load()
    }

    public var unlockedIDs: Set<Int> { storedIDs }

    public func isUnlocked(_ achievement: Achievement) -> Bool {
        storedIDs.contains(achievement.id)
    }

    /// Проверяет каталог и сохраняет новые достижения. Возвращает новые.
    @discardableResult
    public func evaluate(catalog: [Achievement], stats: PlayerStats) -> [Achievement] {
        let fresh = AchievementEngine.newlyUnlocked(catalog: catalog, stats: stats, known: unlockedIDs)
        guard !fresh.isEmpty else { return [] }
        fresh.forEach { storedIDs.insert($0.id) }
        save()
        return fresh
    }

    public func reset() {
        storedIDs.removeAll()
        save()
    }

    // MARK: - Хранение

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let ids = try? decoder.decode([Int].self, from: data) {
            storedIDs = Set(ids)
        }
    }

    private func save() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(storedIDs.sorted()) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
