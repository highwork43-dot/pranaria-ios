import AVFoundation
import Foundation

/// Менеджер звука: фоновая музыка, метроном и звуки смены фазы.
///
/// Файлы берутся из бандла (Content/Audio, конвертированные в .m4a).
final class AudioDirector: NSObject, ObservableObject {

    @Published private(set) var backgroundVolume: Double = 0.6
    @Published private(set) var metronomeEnabled: Bool = false

    private var backgroundPlayer: AVAudioPlayer?
    private var metronomePlayer: AVAudioPlayer?
    private var phasePlayers: [BreathPhaseKind: AVAudioPlayer] = [:]
    private var phaseLoops: [AVAudioPlayer] = []

    private let backgroundNames = ["bg_01", "bg_02", "bg_03"]
    private let metronomeNames = ["metro_01", "metro_02", "metro_03"]

    /// Звуки смены фазы: вдох / задержка / выдох / пауза / финал.
    private func phaseSoundName(for kind: BreathPhaseKind) -> String? {
        switch kind {
        case .inhale: return "phase_01"
        case .holdIn: return "phase_02"
        case .exhale: return "phase_03"
        case .holdOut: return "phase_pause"
        }
    }

    func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: - Background

    func startBackground(named name: String?) {
        stopBackground()
        guard let name, let url = Self.url(forResource: name, extension: "m4a") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(backgroundVolume)
            player.prepareToPlay()
            player.play()
            backgroundPlayer = player
        } catch {
            backgroundPlayer = nil
        }
    }

    func stopBackground() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
    }

    func setBackgroundVolume(_ value: Double) {
        backgroundVolume = value
        backgroundPlayer?.volume = Float(value)
    }

    // MARK: - Metronome

    func setMetronome(enabled: Bool, named name: String?) {
        metronomeEnabled = enabled
        guard enabled, let name, let url = Self.url(forResource: name, extension: "m4a") else {
            metronomePlayer?.stop()
            metronomePlayer = nil
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.5
            player.prepareToPlay()
            player.play()
            metronomePlayer = player
        } catch {
            metronomePlayer = nil
        }
    }

    func stopMetronome() {
        metronomePlayer?.stop()
        metronomePlayer = nil
    }

    // MARK: - Phase cues

    /// Проигрывает звук, соответствующий началу фазы.
    func playPhaseCue(for kind: BreathPhaseKind) {
        guard let name = phaseSoundName(for: kind),
              let url = Self.url(forResource: name, extension: "m4a") else { return }
        if let cached = phasePlayers[kind] {
            cached.currentTime = 0
            cached.play()
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.8
            player.prepareToPlay()
            player.play()
            phasePlayers[kind] = player
        } catch {
            break
        }
    }

    func playFinishCue() {
        guard let url = Self.url(forResource: "phase_end", extension: "m4a") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.9
            player.play()
            phaseLoops.append(player)
        } catch {
            break
        }
    }

    func stopAll() {
        stopBackground()
        stopMetronome()
        phasePlayers.values.forEach { $0.stop() }
        phaseLoops.forEach { $0.stop() }
        phaseLoops.removeAll()
    }

    // MARK: - Helpers

    static func url(forResource name: String, extension ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio") {
            return url
        }
        // Fallback для тестов/CLI: ищем рядом с исходниками.
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd
            .appendingPathComponent("Content/Audio/\(name).\(ext)")
            .asURL
            .flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }

    static var availableBackgrounds: [String] { ["bg_01", "bg_02", "bg_03"] }
    static var availableMetronomes: [String] { ["metro_01", "metro_02", "metro_03"] }
}
