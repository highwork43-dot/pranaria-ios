import SwiftUI
import UIKit

/// Экран тренировки: дыхательный круг, фаза, таймер, голосовые инструкции.
struct SessionView: View {
    let plan: ProgramPlan

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var progress: ProgressController
    @EnvironmentObject private var catalog: CatalogController

    @StateObject private var controller = SessionController()
    @StateObject private var audio = AudioDirector()
    @StateObject private var speech = SpeechDirector()

    @AppStorage("session.haptics") private var hapticsEnabled = true
    @AppStorage("session.background") private var backgroundSound = "bg_01"
    @AppStorage("session.metronome") private var metronomeSound = "metro_01"
    @AppStorage("session.metronomeOn") private var metronomeOn = false
    @AppStorage("session.voice") private var voiceEnabled = false

    @State private var finished = false

    var body: some View {
        ZStack {
            Color(hex: plan.program.backgroundColor)
                .opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                BreathingCircle(
                    progress: controller.phaseProgress,
                    kind: controller.phaseKind,
                    color: Color(hex: plan.program.backgroundColor)
                )
                .frame(maxWidth: 300, maxHeight: 300)

                phaseLabel
                timerLabel
                controls
            }
            .padding()
        }
        .onAppear {
            audio.configureSession()
            speech.configure()
            speech.isEnabled = voiceEnabled

            controller.onPhaseChange = { kind in
                audio.playPhaseCue(for: kind)
                speech.speakPhase(kind)
                if hapticsEnabled { Haptics.phaseChange(kind) }
                speech.speakCycle(current: controller.currentCycle, total: controller.totalCycles)
            }
            controller.onFinish = { program in
                audio.playFinishCue()
                speech.speakFinish()
                if hapticsEnabled { Haptics.success() }
                progress.addSession(
                    SessionRecord(
                        programId: program.id,
                        programName: program.name,
                        duration: plan.totalDuration,
                        completedRepeats: plan.cycleCount,
                        difficulty: plan.difficulty,
                        isMeditation: program.isMeditation
                    )
                )
                progress.refreshAchievements(catalog: catalog.achievements)
                finished = true
            }

            progress.trackStart(programId: plan.program.id)
            controller.start(plan: plan)
            audio.startBackground(named: backgroundSound)
            audio.setMetronome(enabled: metronomeOn, named: metronomeSound)
            speech.speakStart(programName: plan.program.name)
        }
        .onDisappear {
            controller.stop()
            audio.stopAll()
            speech.stop()
        }
        .alert("Тренировка завершена", isPresented: $finished) {
            Button("Закрыть") { dismiss() }
        } message: {
            Text("Отличная работа! Всего тренировок: \(progress.totalSessions).")
        }
    }

    private var header: some View {
        HStack {
            Button {
                progress.trackAbort(programId: plan.program.id, seconds: controller.elapsed)
                controller.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(plan.program.name)
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 30, height: 30)
        }
    }

    private var phaseLabel: some View {
        VStack(spacing: 6) {
            Text(controller.phaseKind?.ruTitle ?? "Готовимся")
                .font(.largeTitle.weight(.semibold))
            Text("Цикл \(controller.currentCycle) из \(controller.totalCycles)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var timerLabel: some View {
        VStack(spacing: 2) {
            Text(format(controller.remainingInPhase))
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
            Text("осталось в фазе")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 36) {
            Button {
                metronomeOn.toggle()
                audio.setMetronome(enabled: metronomeOn, named: metronomeSound)
            } label: {
                Image(systemName: metronomeOn ? "metronome.fill" : "metronome")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            Button {
                if controller.state == .running {
                    controller.pause()
                } else {
                    controller.resume()
                }
            } label: {
                Image(systemName: controller.state == .running ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .buttonStyle(.plain)

            Button {
                hapticsEnabled.toggle()
            } label: {
                Image(systemName: hapticsEnabled ? "waveform.circle.fill" : "waveform.circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
    }

    private func format(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

/// Анимированный дыхательный круг.
struct BreathingCircle: View {
    let progress: Double
    let kind: BreathPhaseKind?
    var color: Color = .accentColor

    /// Радиус круга: 0.35 на выдохе → 1.0 на вдохе.
    private var scale: Double { 0.35 + 0.65 * progress }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 2)
                .padding(8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.35), color.opacity(0.08)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .scaleEffect(scale)

            Circle()
                .stroke(color, lineWidth: 4)
                .scaleEffect(scale)

            VStack(spacing: 4) {
                Image(systemName: kind?.systemImage ?? "circle")
                    .font(.system(size: 34))
                    .foregroundStyle(color)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.linear(duration: 0.05), value: scale)
    }
}

/// Тактильная отдача по фазам.
enum Haptics {
    static func phaseChange(_ kind: BreathPhaseKind) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch kind {
        case .inhale: style = .light
        case .exhale: style = .medium
        default: style = .rigid
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
