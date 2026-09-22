import AppKit
import Combine
import TimerCore

enum NotchScreen {
    case compact, controls, duration, customDuration, mode
}

@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var engine = TimerEngine()
    @Published private(set) var now: TimeInterval = 0
    @Published var notchScreen: NotchScreen = .compact
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var buttonSoundsEnabled: Bool {
        didSet { UserDefaults.standard.set(buttonSoundsEnabled, forKey: "buttonSoundsEnabled") }
    }
    private let buttonSound = NSSound(named: "Tink")
    private var lastButtonSound: TimeInterval = -.infinity
    private let clock = ContinuousClock()
    private let origin = ContinuousClock.now
    private var ticker: AnyCancellable?

    init() {
        let defaults = UserDefaults.standard
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        buttonSoundsEnabled = defaults.object(forKey: "buttonSoundsEnabled") as? Bool ?? true
        buttonSound?.volume = 0.22
        if let duration = defaults.object(forKey: "duration") as? Double {
            engine.setDuration(duration)
        }
    }

    var time: String { TimerEngine.formatted(engine.value(at: now), countdown: engine.mode == .timer) }
    var status: String {
        if engine.isFinished { return "Time’s up" }
        if engine.isRunning { return engine.mode == .timer ? "Counting down" : "Counting up" }
        return engine.elapsed(at: now) > 0 ? "Paused" : "Ready when you are"
    }
    var progress: Double { engine.mode == .timer ? 1 - engine.value(at: now) / engine.duration : 0 }

    private func timestamp() -> TimeInterval {
        let components = origin.duration(to: clock.now).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    func playButtonSound() {
        guard buttonSoundsEnabled else { return }
        let time = timestamp()
        guard time - lastButtonSound >= 0.08 else { return }
        lastButtonSound = time
        buttonSound?.stop()
        buttonSound?.play()
    }

    func toggle() {
        tick()
        if engine.isRunning {
            engine.pause(at: now)
            ticker = nil
        } else {
            engine.start(at: now)
            ticker = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect().sink { [weak self] _ in
                    MainActor.assumeIsolated { self?.tick() }
                }
        }
    }

    func tick() {
        now = timestamp()
        if engine.update(at: now) {
            ticker = nil
            if soundEnabled { NSSound(named: "Glass")?.play() }
        }
    }

    func reset() { ticker = nil; engine.reset(); now = timestamp() }
    func setMode(_ mode: TimerMode) {
        guard !engine.isRunning else { return }
        engine.setMode(mode)
    }
    func setDuration(_ seconds: TimeInterval) {
        guard !engine.isRunning else { return }
        engine.setDuration(seconds)
        UserDefaults.standard.set(engine.duration, forKey: "duration")
    }
}
