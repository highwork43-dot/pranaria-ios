import Foundation

/// Расчёт конкретного плана тренировки из программы и уровня сложности.
///
/// Математика повторяет оригинал (класс `MCycle`):
///
///     breatheTime[i] = fixed ? proportion
///                                : (multiply ? proportion * k : proportion + k)
///                                  * timeInProportion
///
/// где `k` — значение шага выбранного уровня сложности, а `timeInProportion` —
/// длительность одной «доли».
public struct ProgramPlan {

    /// Один шаг плана: одна фаза с готовой длительностью.
    public struct Step: Equatable {
        public var cycleIndex: Int
        public var repeatIndex: Int
        public var phase: BreathPhase

        public init(cycleIndex: Int, repeatIndex: Int, phase: BreathPhase) {
            self.cycleIndex = cycleIndex
            self.repeatIndex = repeatIndex
            self.phase = phase
        }
    }

    public let program: Program
    public let difficulty: Int
    public let steps: [Step]

    /// Полная длительность плана в секундах.
    public var totalDuration: Double {
        steps.reduce(0) { $0 + $1.phase.seconds }
    }

    /// Число полных циклов.
    public var cycleCount: Int {
        program.cycles.reduce(0) { $0 + max(1, $1.repeats) }
    }

    /// Пропорции фаз первого цикла — для подписи «4–4–4–4».
    public var proportionsDescription: String {
        guard let first = program.cycles.first else { return "" }
        let adjustment = Self.adjustment(for: program, level: difficulty)
        return first.phases
            .map { spec -> String in
                let seconds = Self.resolvedSeconds(
                    spec, cycle: first, adjustment: adjustment, baseTip: program.timeInProportion
                )
                return String(Int(seconds.rounded()))
            }
            .joined(separator: "–")
    }

    // MARK: - Build

    public static func make(program: Program, difficulty: Int) -> ProgramPlan {
        let level = max(0, min(difficulty, program.maxDifficulty))
        let adjustment = adjustment(for: program, level: level)

        var steps: [Step] = []
        for (cycleIndex, cycle) in program.cycles.enumerated() {
            let repeats = max(1, cycle.repeats)
            for repeatIndex in 0..<repeats {
                for spec in cycle.phases {
                    let seconds = resolvedSeconds(
                        spec,
                        cycle: cycle,
                        adjustment: adjustment,
                        baseTip: program.timeInProportion
                    )
                    guard seconds > 0 else { continue }
                    steps.append(
                        Step(
                            cycleIndex: cycleIndex,
                            repeatIndex: repeatIndex,
                            phase: BreathPhase(kind: kind(for: spec.kind), seconds: seconds)
                        )
                    )
                }
            }
        }
        return ProgramPlan(program: program, difficulty: level, steps: steps)
    }

    // MARK: - Math

    /// Поправка сложности для выбранного уровня.
    ///
    /// В оригинале хранится список `difficultyIncreaser` из 4 (или 6) чисел:
    ///  * в аддитивном режиме — на сколько увеличить долю фазы на этом уровне;
    ///  * в мультипликативном режиме (флаг в 6-м элементе шага) — коэффициент,
    ///    на который умножается доля фазы.
    ///
    /// Значение берётся из шага выбранного уровня (а не разница с предыдущим):
    /// в мультипликативном режиме это однозначно (значение шага = коэффициент),
    /// и в аддитивном это даёт монотонно растущую шкалу «уровень → добавка».
    private struct Adjustment {
        var deltas: [Double]
        var multiply: Bool
    }

    private static func adjustment(for program: Program, level: Int) -> Adjustment {
        let empty = Adjustment(deltas: [0, 0, 0, 0], multiply: false)
        guard level > 0, level < program.difficultySteps.count else { return empty }

        let current = program.difficultySteps[level]
        let multiply = current.multiply

        var deltas: [Double] = []
        for index in 0..<4 {
            deltas.append(index < current.phases.count ? current.phases[index] : 0)
        }
        return Adjustment(deltas: deltas, multiply: multiply)
    }

    /// `baseTip` — длительность «доли» из настроек программы
    /// (`timeInProportionDefault` в оригинале). Цикл может переопределить её
    /// собственным модификатором `:p`.
    private static func resolvedSeconds(
        _ spec: Program.PhaseSpec,
        cycle: Program.CycleSpec,
        adjustment: Adjustment,
        baseTip: Double
    ) -> Double {
        let tip = cycle.timeInProportion ?? baseTip
        if spec.fixed {
            // Фиксированная фаза: время в секундах, без умножения и без поправки.
            return spec.proportion
        }
        let delta = adjustment.deltas.indices.contains(spec.phaseIndex) ? adjustment.deltas[spec.phaseIndex] : 0
        let adjusted = adjustment.multiply ? spec.proportion * delta : spec.proportion + delta
        return max(0, adjusted * tip)
    }

    private static func kind(for raw: String) -> BreathPhaseKind {
        BreathPhaseKind(rawValue: raw) ?? .inhale
    }
}

extension Program.PhaseSpec {
    /// Индекс фазы в цикле (вдох/задержка/выдох/пауза).
    var phaseIndex: Int {
        switch kind {
        case "inhale": return 0
        case "holdIn": return 1
        case "exhale": return 2
        case "holdOut": return 3
        default: return 0
        }
    }
}
