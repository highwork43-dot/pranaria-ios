import Foundation

/// Движок дыхательной сессии.
///
/// Чистая логика тайминга без UI и без Combine — ядро одинаково работает на
/// iOS и Linux, поэтому полностью покрывается тестами.
///
/// Время считается по «накопленному дельте»: вызывающий передаёт
/// `tick(delta:)`, а движок сам разбирается, сколько фаз успело пройти.
public final class BreathSession {

    public enum State: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    /// Один шаг плоского таймлайна сессии.
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

    // MARK: - Состояние

    public private(set) var state: State = .idle
    public private(set) var stepIndex: Int = 0
    public private(set) var phaseProgress: Double = 0
    public private(set) var remainingInPhase: Double = 0
    public private(set) var elapsed: Double = 0
    public private(set) var remaining: Double = 0
    public private(set) var completedSteps: Int = 0

    /// Вызывается при смене фазы — звуки и тактильная отдача.
    public var onPhaseChange: ((BreathPhaseKind) -> Void)?
    /// Вызывается один раз в конце сессии.
    public var onFinish: ((Program) -> Void)?

    private var plan: ProgramPlan?
    private var timeline: [Step] = []

    // MARK: - Жизненный цикл

    public init() {}

    public func start(_ plan: ProgramPlan) {
        self.plan = plan
        timeline = Self.makeTimeline(for: plan)
        elapsed = 0
        remaining = plan.totalDuration
        stepIndex = 0
        completedSteps = 0
        phaseProgress = 0
        remainingInPhase = timeline.first?.phase.seconds ?? 0
        state = .running
        if let first = timeline.first {
            onPhaseChange?(first.phase.kind)
        }
    }

    public func pause() {
        guard state == .running else { return }
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        state = .running
    }

    public func stop() {
        state = .idle
        stepIndex = 0
        phaseProgress = 0
        elapsed = 0
        remaining = 0
        completedSteps = 0
        timeline = []
    }

    // MARK: - Тик

    /// Продвигает сессию на `delta` секунд. Возвращает `true`, если сессия
    /// только что завершилась.
    @discardableResult
    public func tick(delta: TimeInterval) -> Bool {
        guard state == .running, !timeline.isEmpty, delta > 0 else { return false }

        var remainingDelta = delta
        while remainingDelta > 0, stepIndex < timeline.count {
            let phase = timeline[stepIndex].phase
            let left = remainingInPhase - remainingDelta

            if left > 0 {
                remainingInPhase = left
                phaseProgress = phase.seconds > 0 ? 1 - left / phase.seconds : 1
                elapsed += remainingDelta
                remaining = max(0, remaining - remainingDelta)
                remainingDelta = 0
                break
            }

            // Фаза завершена — доучитываем остаток фазы (remainingInPhase)
            // и переходим к следующей.
            elapsed += remainingInPhase
            remaining = max(0, remaining - remainingInPhase)
            remainingDelta = -left
            completedSteps += 1
            stepIndex += 1

            if stepIndex >= timeline.count {
                finish()
                return true
            }
            remainingInPhase = timeline[stepIndex].phase.seconds
            phaseProgress = 0
            onPhaseChange?(timeline[stepIndex].phase.kind)
        }
        return false
    }

    private func finish() {
        state = .finished
        if let plan { onFinish?(plan.program) }
    }

    // MARK: - Производные значения

    public var currentStep: Step? {
        guard stepIndex >= 0, stepIndex < timeline.count else { return nil }
        return timeline[stepIndex]
    }

    public var currentPhase: BreathPhase? { currentStep?.phase }
    public var currentPhaseKind: BreathPhaseKind? { currentStep?.phase.kind }
    public var currentPhaseRemaining: Double { remainingInPhase }

    /// Радиус круга 0…1: растёт на вдохе, сжимается на выдохе.
    public var circleScale: Double {
        guard let phase = currentPhase else { return 0 }
        switch phase.kind {
        case .inhale: return phaseProgress
        case .exhale: return 1 - phaseProgress
        case .holdIn: return 1
        case .holdOut: return 0
        }
    }

    public var progress: Double {
        let total = plan?.totalDuration ?? 0
        guard total > 0 else { return 0 }
        return min(1, max(0, elapsed / total))
    }

    public var totalSteps: Int { timeline.count }

    /// Номер текущего цикла (с 1) и общее число циклов.
    public var currentCycleNumber: Int { (currentStep?.cycleIndex ?? 0) + 1 }
    public var totalCycles: Int { max(1, plan?.cycleCount ?? 1) }

    // MARK: - Таймлайн

    /// Разворачивает готовый план в плоский список шагов (каждый шаг — одна фаза).
    public static func makeTimeline(for plan: ProgramPlan) -> [Step] {
        plan.steps.map { step in
            Step(
                cycleIndex: step.cycleIndex,
                repeatIndex: step.repeatIndex,
                phase: step.phase
            )
        }
    }
}
