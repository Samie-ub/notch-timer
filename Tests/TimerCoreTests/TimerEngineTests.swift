import Testing
@testable import TimerCore

@Test func countdownPauseResumeExcludesPausedTime() {
    var timer = TimerEngine()
    timer.setDuration(60)
    timer.start(at: 100)
    #expect(timer.value(at: 110) == 50)
    timer.pause(at: 115)
    #expect(timer.value(at: 200) == 45)
    timer.start(at: 200)
    #expect(timer.value(at: 210) == 35)
}

@Test func delayedTickFinishesExactlyOnceAndCanRestart() {
    var timer = TimerEngine()
    timer.setDuration(5)
    timer.start(at: 0)
    let completed = timer.update(at: 3600)
    #expect(completed)
    #expect(timer.isFinished)
    #expect(!timer.isRunning)
    #expect(timer.value(at: 3600) == 0)
    let completedAgain = timer.update(at: 3601)
    #expect(!completedAgain)
    timer.start(at: 3602)
    #expect(!timer.isFinished)
    #expect(timer.value(at: 3603) == 4)
}

@Test func stopwatchTracksElapsedAcrossPauses() {
    var timer = TimerEngine()
    timer.setMode(.stopwatch)
    timer.start(at: 0)
    timer.pause(at: 10.5)
    timer.start(at: 100)
    #expect(timer.value(at: 105.5) == 16)
    let completed = timer.update(at: 10000)
    #expect(!completed)
    timer.reset()
    #expect(timer.value(at: 10000) == 0)
    #expect(!timer.isRunning)
}

@Test func switchingModeResetsSessionAndPreservesDuration() {
    var timer = TimerEngine()
    timer.setDuration(90)
    timer.start(at: 0)
    timer.setMode(.stopwatch)
    #expect(!timer.isRunning)
    #expect(timer.value(at: 10) == 0)
    timer.setMode(.timer)
    #expect(timer.value(at: 10) == 90)
}

@Test func zeroDurationClampedAndFormattingDoesNotShowZeroEarly() {
    var timer = TimerEngine()
    timer.setDuration(0)
    #expect(timer.duration == 1)
    timer.setDuration(.infinity)
    #expect(timer.duration == 1)
    #expect(TimerEngine.formatted(0.1, countdown: true) == "00:01")
    #expect(TimerEngine.formatted(59.9, countdown: false) == "00:59")
    #expect(TimerEngine.formatted(3601, countdown: false) == "1:00:01")
}

@Test func pauseAtDeadlineCompletesAndDuplicateStartDoesNotLoseTime() {
    var timer = TimerEngine()
    timer.setDuration(10)
    timer.start(at: 0)
    timer.start(at: 5)
    #expect(timer.value(at: 6) == 4)
    timer.pause(at: 10)
    #expect(timer.isFinished)
    #expect(!timer.isRunning)
}
