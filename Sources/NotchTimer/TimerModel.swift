import AppKit
import Combine
import TimerCore

enum NotchScreen {
    case compact, controls, duration, customDuration, mode, browserFocus

    var isFeaturePanel: Bool { self == .browserFocus }
}

@MainActor
final class TimerModel: ObservableObject {
    let browserFocus = BrowserFocusController()
    @Published var featurePanelSize = CGSize(width: 360, height: 560)
    @Published private(set) var engine = TimerEngine()
    @Published private(set) var now: TimeInterval = 0
    @Published var notchScreen: NotchScreen = .compact
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    private let startSound: NSSound?
    private let pauseSound: NSSound?
    private let stopSound: NSSound?
    private let timesUpSound: NSSound?
    private let clock = ContinuousClock()
    private let origin = ContinuousClock.now
    private var ticker: AnyCancellable?

    init() {
        let defaults = UserDefaults.standard
        startSound = TimerModel.loadSound("start")
        pauseSound = TimerModel.loadSound("pause")
        stopSound = TimerModel.loadSound("stop")
        timesUpSound = TimerModel.loadSound("times-up")
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        if let duration = defaults.object(forKey: "duration") as? Double {
            engine.setDuration(duration)
        }
        browserFocus.changed = { [weak self] in self?.syncBrowserFocus() }
        syncBrowserFocus()
    }

    private func syncBrowserFocus() {
        browserFocus.synchronize(engine: engine, now: now)
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

    private static func loadSound(_ name: String) -> NSSound? {
        let extensions = name == "start" ? ["m4a", "mp3"] : ["mp3"]
        let roots = [Bundle.main.resourceURL,
                     URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
            .compactMap { $0 }
        for ext in extensions {
            for root in roots {
                let url = root.appendingPathComponent("sounds/\(name).\(ext)")
                if FileManager.default.fileExists(atPath: url.path),
                   let sound = NSSound(contentsOf: url, byReference: false) {
                    return sound
                }
            }
        }
        return nil
    }

    func toggle() {
        defer { syncBrowserFocus() }
        tick()
        if engine.isRunning {
            engine.pause(at: now)
            ticker = nil
            pauseSound?.stop()
            pauseSound?.play()
        } else {
            engine.start(at: now)
            startSound?.stop()
            startSound?.play()
            ticker = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect().sink { [weak self] _ in
                    MainActor.assumeIsolated { self?.tick() }
                }
        }
    }

    func tick() {
        defer { syncBrowserFocus() }
        now = timestamp()
        if engine.update(at: now) {
            ticker = nil
            if soundEnabled {
                timesUpSound?.stop()
                timesUpSound?.play()
            }
        }
    }

    func reset() {
        let wasActive = engine.isRunning || (!engine.isFinished && engine.elapsed(at: now) > 0)
        ticker = nil
        engine.reset()
        now = timestamp()
        if wasActive {
            stopSound?.stop()
            stopSound?.play()
        }
        syncBrowserFocus()
    }
    func setMode(_ mode: TimerMode) {
        guard !engine.isRunning else { return }
        engine.setMode(mode)
        syncBrowserFocus()
    }
    func setDuration(_ seconds: TimeInterval) {
        guard !engine.isRunning else { return }
        engine.setDuration(seconds)
        UserDefaults.standard.set(engine.duration, forKey: "duration")
    }
}
