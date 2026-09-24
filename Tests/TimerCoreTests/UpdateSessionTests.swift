import Testing
@testable import TimerCore

@Test func updateRestartWaitsForCountdownIncludingPause() {
    var timer = TimerEngine()
    timer.setDuration(10)
    #expect(!timer.hasUnfinishedSession)
    timer.start(at: 0)
    #expect(timer.hasUnfinishedSession)
    timer.pause(at: 4)
    #expect(timer.hasUnfinishedSession)
    timer.start(at: 20)
    timer.update(at: 26)
    #expect(!timer.hasUnfinishedSession)
    timer.start(at: 30)
    #expect(timer.hasUnfinishedSession)
    timer.reset()
    #expect(!timer.hasUnfinishedSession)
}

@Test func updateRestartWaitsForStopwatchReset() {
    var timer = TimerEngine()
    timer.setMode(.stopwatch)
    timer.start(at: 0)
    timer.update(at: 10000)
    #expect(timer.hasUnfinishedSession)
    timer.pause(at: 10001)
    #expect(timer.hasUnfinishedSession)
    timer.reset()
    #expect(!timer.hasUnfinishedSession)
}
