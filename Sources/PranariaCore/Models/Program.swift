import Foundation

/// Программа дыхания — ровно та структура, что извлечена из оригинального
/// приложения (Content/programs.json), без преобразований.
public struct Program: Codable, Identifiable, Hashable {

    /// Одна фаза цикла в исходном формате: доля от `timeInProportion`.
    public struct PhaseSpec: Codable, Hashable {
        /// inhale | holdIn | exhale | holdOut
        public var kind: String
        public var proportion: Double
        /// true → время фиксировано в секундах и не умножается на timeInProportion.
        public var fixed: Bool

        public init(kind: String, proportion: Double, fixed: Bool) {
            self.kind = kind
            self.proportion = proportion
            self.fixed = fixed
        }
    }

    /// Цикл программы.
    public struct CycleSpec: Codable, Hashable {
        public var phases: [PhaseSpec]
        public var repeats: Int
        public var timeInProportion: Double?
        public var breatheType: Int?
        public var wayInhale: Int?
        public var wayExhale: Int?
        public var swapMethods: Bool

        public init(
            phases: [PhaseSpec],
            repeats: Int,
            timeInProportion: Double? = nil,
            breatheType: Int? = nil,
            wayInhale: Int? = nil,
            wayExhale: Int? = nil,
            swapMethods: Bool = false
        ) {
            self.phases = phases
            self.repeats = repeats
            self.timeInProportion = timeInProportion
            self.breatheType = breatheType
            self.wayInhale = wayInhale
            self.wayExhale = wayExhale
            self.swapMethods = swapMethods
        }
    }

    /// Шаг настройки сложности: доли четырёх фаз + суммарное время.
    public struct DifficultyStep: Codable, Hashable {
        public var phases: [Double]
        public var total: Double
        /// true → прибавление к фазе мультипликативное.
        public var multiply: Bool

        public init(phases: [Double], total: Double, multiply: Bool) {
            self.phases = phases
            self.total = total
            self.multiply = multiply
        }
    }

    public var id: String
    public var index: Int
    public var name: String
    public var shortDescription: String
    public var description: String
    public var category: String
    public var categoryDescription: String
    public var lengthMinutes: Int
    public var difficulty: Int
    /// training | meditation
    public var mode: String
    public var timeInProportion: Double
    public var breatheType: Int
    public var breatheWay: [Int]
    public var soundsSettings: String
    public var backgroundColor: String
    public var icon: String
    public var backgroundImage: String
    public var cycles: [CycleSpec]
    public var difficultySteps: [DifficultyStep]

    public init(
        id: String,
        index: Int,
        name: String,
        shortDescription: String,
        description: String,
        category: String,
        categoryDescription: String,
        lengthMinutes: Int,
        difficulty: Int,
        mode: String,
        timeInProportion: Double,
        breatheType: Int,
        breatheWay: [Int],
        soundsSettings: String,
        backgroundColor: String,
        icon: String,
        backgroundImage: String,
        cycles: [CycleSpec],
        difficultySteps: [DifficultyStep]
    ) {
        self.id = id
        self.index = index
        self.name = name
        self.shortDescription = shortDescription
        self.description = description
        self.category = category
        self.categoryDescription = categoryDescription
        self.lengthMinutes = lengthMinutes
        self.difficulty = difficulty
        self.mode = mode
        self.timeInProportion = timeInProportion
        self.breatheType = breatheType
        self.breatheWay = breatheWay
        self.soundsSettings = soundsSettings
        self.backgroundColor = backgroundColor
        self.icon = icon
        self.backgroundImage = backgroundImage
        self.cycles = cycles
        self.difficultySteps = difficultySteps
    }

    public var isMeditation: Bool { mode == "meditation" }

    /// Максимальный уровень сложности, доступный программе.
    public var maxDifficulty: Int { max(0, difficultySteps.count - 1) }

    /// Человекочитаемая категория.
    public var categoryTitle: String {
        category.isEmpty ? "Прочие" : category
    }
}
