import SwiftUI
import Combine
import UIKit
import AVFoundation

/// Обёртка над `BreathSession` для SwiftUI: тикает таймером и публикует
/// состояние в UI.
@MainActor
final class SessionController: ObservableObject {

    @Published private(set) var state: BreathSession.State = .idle
    @Published private(set) var phaseKind: BreathPhaseKind?
    @Published private(set) var phaseProgress: Double = 0
    @Published private(set) var remainingInPhase: Double = 0
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var remaining: Double = 0
    @Published private(set) var currentCycle: Int = 1
    @Published private(set) var totalCycles: Int = 1

    let session = BreathSession()

    private var timer: Timer?
    private var lastTick: Date?

    /// Колбэки наружу (звук, тактика, аналитика).
    var onPhaseChange: ((BreathPhaseKind) -> Void)?
    var onFinish: ((Program) -> Void)?

    init() {
        session.onPhaseChange = { [weak self] kind in
            self?.phaseKind = kind
            self?.onPhaseChange?(kind)
        }
        session.onFinish = { [weak self] program in
            self?.state = .finished
            self?.onFinish?(program)
        }
    }

    func start(plan: ProgramPlan) {
        session.start(plan)
        sync()
        lastTick = Date()
        startTimer()
    }

    func pause() {
        session.pause()
        stopTimer()
        sync()
    }

    func resume() {
        session.resume()
        lastTick = Date()
        startTimer()
        sync()
    }

    func stop() {
        session.stop()
        stopTimer()
        sync()
    }

    var circleScale: Double { session.circleScale }
    var progress: Double { session.progress }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        t.tolerance = 0.005
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        let now = Date()
        let delta = now.timeIntervalSince(lastTick ?? now)
        lastTick = now
        session.tick(delta: delta)
        sync()
    }

    private func sync() {
        state = session.state
        phaseKind = session.currentPhaseKind
        phaseProgress = session.phaseProgress
        remainingInPhase = session.currentPhaseRemaining
        elapsed = session.elapsed
        remaining = session.remaining
        currentCycle = session.currentCycleNumber
        totalCycles = session.totalCycles
    }
}

/// Голосовые инструкции (TTS) на русском языке.
@MainActor
final class SpeechDirector: ObservableObject {

    @Published var isEnabled: Bool = false
    @Published var speaksPhaseNames: Bool = true
    @Published var speaksGuidance: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenCycle = 0

    func configure() {
        synthesizer.voice = AVSpeechSynthesisVoice(language: "ru-RU")
            ?? AVSpeechSynthesisVoice(language: "ru")
    }

    /// Проговаривает переход в новую фазу.
    func speakPhase(_ kind: BreathPhaseKind) {
        guard isEnabled else { return }
        if speaksGuidance {
            speak(InstructionProvider.phaseGuidance(kind))
        } else if speaksPhaseNames {
            speak(InstructionProvider.phasePhrase(kind))
        }
    }

    func speakStart(programName: String) {
        guard isEnabled else { return }
        speak(InstructionProvider.startPhrase(programName: programName))
    }

    func speakCycle(current: Int, total: Int) {
        guard isEnabled, current != lastSpokenCycle else { return }
        lastSpokenCycle = current
        speak(InstructionProvider.cyclePhrase(current: current, total: total))
    }

    func speakFinish() {
        guard isEnabled else { return }
        speak(InstructionProvider.finishPhrase())
    }

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = synthesizer.voice
        utterance.rate = 0.45
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
