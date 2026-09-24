import Foundation

public enum TimerMode: String, CaseIterable, Codable, Sendable {
    case timer = "Timer"
    case stopwatch = "Stopwatch"
}

/// Elapsed time comes from timestamps, never from the number of UI refreshes.
public struct TimerEngine: Sendable {
    public private(set) var mode: TimerMode = .timer
    public private(set) var duration: TimeInterval = 25 * 60
    public private(set) var isRunning = false
    public private(set) var isFinished = false
    private var accumulated: TimeInterval = 0
    private var startedAt: TimeInterval?

    public init() {}

    public func snapshot(at now: TimeInterval, wallTime: TimeInterval) -> TimerSessionSnapshot {
        TimerSessionSnapshot(mode: mode, duration: duration, elapsed: elapsed(at: now),
                             isRunning: isRunning, isFinished: isFinished, savedAt: wallTime)
    }

    public init?(snapshot: TimerSessionSnapshot, now: TimeInterval, wallTime: TimeInterval) {
        guard snapshot.duration.isFinite, (1...5999).contains(snapshot.duration),
              snapshot.elapsed.isFinite, snapshot.elapsed >= 0,
              snapshot.savedAt.isFinite, wallTime.isFinite, now.isFinite else { return nil }
        mode = snapshot.mode
        duration = snapshot.duration
        let downtime = snapshot.isRunning ? max(0, wallTime - snapshot.savedAt) : 0
        accumulated = snapshot.elapsed + downtime
        guard accumulated.isFinite, accumulated <= 1e12 else { return nil }
        isFinished = mode == .timer && (snapshot.isFinished || accumulated >= duration)
        if isFinished { accumulated = duration }
        isRunning = snapshot.isRunning && !isFinished
        startedAt = isRunning ? now : nil
    }

    public func elapsed(at now: TimeInterval) -> TimeInterval {
        accumulated + (startedAt.map { max(0, now - $0) } ?? 0)
    }

    public func value(at now: TimeInterval) -> TimeInterval {
        mode == .timer ? max(0, duration - elapsed(at: now)) : elapsed(at: now)
    }

    public mutating func setMode(_ mode: TimerMode) {
        guard self.mode != mode else { return }
        self.mode = mode
        reset()
    }

    public mutating func setDuration(_ seconds: TimeInterval) {
        guard seconds.isFinite else { return }
        duration = min(5999, max(1, seconds))
        reset()
    }

    public mutating func start(at now: TimeInterval) {
        guard !isRunning else { return }
        if isFinished { reset() }
        startedAt = now
        isRunning = true
    }

    public mutating func pause(at now: TimeInterval) {
        guard isRunning else { return }
        if update(at: now) { return }
        accumulated = elapsed(at: now)
        startedAt = nil
        isRunning = false
    }

    /// Returns true exactly once per completed countdown.
    @discardableResult
    public mutating func update(at now: TimeInterval) -> Bool {
        guard isRunning, mode == .timer, elapsed(at: now) >= duration else { return false }
        accumulated = duration
        startedAt = nil
        isRunning = false
        isFinished = true
        return true
    }

    public mutating func reset() {
        accumulated = 0
        startedAt = nil
        isRunning = false
        isFinished = false
    }

    public static func formatted(_ interval: TimeInterval, countdown: Bool) -> String {
        let seconds = Int(countdown ? ceil(max(0, interval)) : floor(max(0, interval)))
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// Only persisted for an explicit updater restart, not ordinary quits.
public struct TimerSessionSnapshot: Codable, Sendable {
    public let mode: TimerMode
    public let duration: TimeInterval
    public let elapsed: TimeInterval
    public let isRunning: Bool
    public let isFinished: Bool
    public let savedAt: TimeInterval
}
