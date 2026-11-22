import Foundation

/// Тип фазы дыхательного цикла.
///
/// Порядок фаз в цикле: вдох → задержка → выдох → пауза.
public enum BreathPhaseKind: String, Codable, CaseIterable, Sendable {
    case inhale
    case holdIn
    case exhale
    case holdOut

    public var ruTitle: String {
        switch self {
        case .inhale: return "Вдох"
        case .holdIn: return "Задержка"
        case .exhale: return "Выдох"
        case .holdOut: return "Пауза"
        }
    }

    public var enTitle: String {
        switch self {
        case .inhale: return "Inhale"
        case .holdIn: return "Hold"
        case .exhale: return "Exhale"
        case .holdOut: return "Rest"
        }
    }

    public var systemImage: String {
        switch self {
        case .inhale: return "arrow.up.circle"
        case .holdIn: return "pause.circle"
        case .exhale: return "arrow.down.circle"
        case .holdOut: return "circle"
        }
    }

    /// Направление изменения радиуса анимации круга.
    public var grows: Bool {
        self == .inhale
    }
}

/// Одна фаза дыхательного цикла с готовой длительностью в секундах.
public struct BreathPhase: Codable, Hashable, Identifiable, Sendable {
    public var kind: BreathPhaseKind
    public var seconds: Double

    public var id: String { "\(kind.rawValue)-\(seconds)" }

    public init(kind: BreathPhaseKind, seconds: Double) {
        self.kind = kind
        self.seconds = max(0, seconds)
    }
}
