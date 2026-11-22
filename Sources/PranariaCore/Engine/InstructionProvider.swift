import Foundation

/// Текстовые инструкции и реплики голосового сопровождения.
///
/// Ядро отдаёт готовые строки — их озвучивает AVSpeechSynthesizer в
/// iOS-слое. Так формулировки можно тестировать на Linux.
public enum InstructionProvider {

    // MARK: - Озвучивание фаз

    /// Краткая реплика фазы для голосового сопровождения.
    public static func phasePhrase(_ kind: BreathPhaseKind) -> String {
        switch kind {
        case .inhale: return "Вдох"
        case .holdIn: return "Задержка"
        case .exhale: return "Выдох"
        case .holdOut: return "Пауза"
        }
    }

    /// Развёрнутая подсказка по фазе (для режима «подробные инструкции»).
    public static func phaseGuidance(_ kind: BreathPhaseKind) -> String {
        switch kind {
        case .inhale:
            return "Вдохните носом медленно и глубоко, наполняя низ живота."
        case .holdIn:
            return "Задержите дыхание, не напрягаясь."
        case .exhale:
            return "Выдохните ртом медленно и плавно, расслабляя плечи."
        case .holdOut:
            return "Пауза — отдохните перед следующим вдохом."
        }
    }

    // MARK: - Озвучивание событий

    public static func startPhrase(programName: String) -> String {
        "Начинаем тренировку: \(programName)."
    }

    public static func cyclePhrase(current: Int, total: Int) -> String {
        "Цикл \(current) из \(total)."
    }

    public static func finishPhrase() -> String {
        "Тренировка завершена. Отличная работа."
    }

    public static func pausePhrase() -> String { "Пауза." }
    public static func resumePhrase() -> String { "Продолжаем." }

    // MARK: - Инструкции по технике

    /// Пояснение по пропорциям программы: «вдох 4 секунды, задержка 4, выдох 4…».
    public static func proportionsExplanation(for plan: ProgramPlan) -> String {
        guard let first = plan.program.cycles.first else { return "" }
        let parts = first.phases.enumerated().compactMap { index, spec -> String? in
            let seconds = plan.phaseSeconds(index: index, spec: spec)
            guard seconds > 0 else { return nil }
            let name = BreathPhaseKind(rawValue: spec.kind)?.ruTitle.lowercased() ?? spec.kind
            return "\(name) \(format(seconds))"
        }
        guard !parts.isEmpty else { return "" }
        return "Дыхание: " + parts.joined(separator: ", ") + "."
    }

    /// Краткая памятка к технике (описание программы + пропорции).
    public static func techniqueBriefing(for plan: ProgramPlan) -> String {
        let program = plan.program
        var lines: [String] = []
        if !program.shortDescription.isEmpty {
            lines.append(program.shortDescription)
        }
        let proportions = proportionsExplanation(for: plan)
        if !proportions.isEmpty {
            lines.append(proportions)
        }
        lines.append("Дышите спокойно, без усилия. Если чувствуете дискомфорт — вернитесь к обычному дыханию.")
        return lines.joined(separator: "\n\n")
    }

    /// Общие правила практики (раздел «Инструкции» в приложении).
    public static let generalInstructions: [String] = [
        "Сядьте прямо, расслабьте плечи и опустите челюсть.",
        "Положите язык за верхние зубы, как в позе Айенгар.",
        "Дышите через нос, если это не вызывает дискомфорта.",
        "Во время задержки не напрягайте лицо и не задерживайте дыхание слишком долго.",
        "Если появляется головокружение — прервите практику и подышите обычно.",
        "Занимайтесь регулярно: 1–2 подхода в день дают результат быстрее, чем один длинный."
    ]

    /// Подсказки по способам дыхания (breatheWay 1…4 из оригинала).
    public static func breathingWayDescription(_ index: Int) -> String {
        switch index {
        case 1: return "Грудное дыхание: вдох грудной клеткой, живот остаётся спокойным."
        case 2: return "Диафрагмальное (брюшное) дыхание: вдох наполняет живот, грудь почти неподвижна."
        case 3: return "Полноценное дыхание: вдох задействует и живот, и грудную клетку."
        case 4: return "Свободное дыхание: естественный ритм без контроля."
        default: return ""
        }
    }

    private static func format(_ seconds: Double) -> String {
        let value = seconds.rounded()
        if value == value.rounded() {
            return "\(Int(value)) \(secondsWord(Int(value)))"
        }
        return String(format: "%.1f %@", seconds, secondsWord(Int(value.rounded())))
    }

    private static func secondsWord(_ value: Int) -> String {
        let mod100 = value % 100
        let mod10 = value % 10
        if (11...14).contains(mod100) { return "секунд" }
        switch mod10 {
        case 1: return "секунда"
        case 2...4: return "секунды"
        default: return "секунд"
        }
    }
}

private extension ProgramPlan {
    /// Время фазы по индексу (0 — вдох, 1 — задержка, 2 — выдох, 3 — пауза).
    func phaseSeconds(index: Int, spec: Program.PhaseSpec) -> Double {
        let step = steps.first { step in
            step.phase.kind.rawValue == spec.kind
        }
        return step?.phase.seconds ?? 0
    }
}
