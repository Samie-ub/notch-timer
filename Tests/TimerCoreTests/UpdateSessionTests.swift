import Foundation
import Testing
@testable import TimerCore

@Test func runningCountdownSurvivesUpdateAndCountsRestartTime() throws {
    var timer = TimerEngine()
    timer.setDuration(60)
    timer.start(at: 100)
    let snapshot = timer.snapshot(at: 110, wallTime: 1000)
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(TimerSessionSnapshot.self, from: data)
    let restored = try #require(TimerEngine(snapshot: decoded, now: 0, wallTime: 1005))
    #expect(restored.isRunning)
    #expect(restored.value(at: 0) == 45)
    #expect(restored.value(at: 10) == 35)
}

@Test func pausedCountdownSurvivesUpdateWithoutCountingDowntime() throws {
    var timer = TimerEngine()
    timer.setDuration(60)
    timer.start(at: 100)
    timer.pause(at: 110)
    var restored = try #require(TimerEngine(snapshot: timer.snapshot(at: 110, wallTime: 1000), now: 0, wallTime: 1100))
    #expect(!restored.isRunning)
    #expect(restored.value(at: 100) == 50)
    restored.start(at: 100)
    #expect(restored.value(at: 105) == 45)
}

@Test func countdownFinishesDuringUpdateExactlyOnce() throws {
    var timer = TimerEngine()
    timer.setDuration(10)
    timer.start(at: 0)
    var restored = try #require(TimerEngine(snapshot: timer.snapshot(at: 8, wallTime: 1000), now: 0, wallTime: 1005))
    #expect(restored.isFinished)
    #expect(!restored.isRunning)
    #expect(restored.value(at: 0) == 0)
    let completedAgain = restored.update(at: 1)
    #expect(!completedAgain)
    restored.start(at: 2)
    #expect(restored.value(at: 3) == 9)
}

@Test func runningAndPausedStopwatchSurviveUpdate() throws {
    var timer = TimerEngine()
    timer.setMode(.stopwatch)
    timer.start(at: 0)
    let running = try #require(TimerEngine(snapshot: timer.snapshot(at: 10, wallTime: 1000), now: 0, wallTime: 1005))
    #expect(running.mode == .stopwatch)
    #expect(running.isRunning)
    #expect(running.value(at: 3) == 18)
    timer.pause(at: 10)
    let paused = try #require(TimerEngine(snapshot: timer.snapshot(at: 10, wallTime: 1000), now: 0, wallTime: 1100))
    #expect(!paused.isRunning)
    #expect(paused.value(at: 3) == 10)
}

@Test func idleAndCompletedSessionsRemainStopped() throws {
    var timer = TimerEngine()
    let idle = try #require(TimerEngine(snapshot: timer.snapshot(at: 0, wallTime: 1000), now: 0, wallTime: 1010))
    #expect(!idle.isRunning)
    #expect(idle.value(at: 10) == timer.duration)
    timer.start(at: 0)
    timer.update(at: timer.duration)
    let completed = try #require(TimerEngine(snapshot: timer.snapshot(at: timer.duration, wallTime: 1000), now: 0, wallTime: 1010))
    #expect(completed.isFinished)
    #expect(!completed.isRunning)
}

@Test func clockRollbackDoesNotAddTimeAndInvalidSnapshotsAreRejected() throws {
    var timer = TimerEngine()
    timer.start(at: 0)
    let snapshot = timer.snapshot(at: 10, wallTime: 1000)
    let restored = try #require(TimerEngine(snapshot: snapshot, now: 0, wallTime: 900))
    #expect(restored.elapsed(at: 0) == 10)
    let invalid = TimerSessionSnapshot(mode: .timer, duration: 60, elapsed: .infinity,
                                       isRunning: true, isFinished: false, savedAt: 1000)
    #expect(TimerEngine(snapshot: invalid, now: 0, wallTime: 1005) == nil)
}
