import Testing
@testable import TimerCore

@Test func focusDomainsNormalizeURLsAndRejectRuleSyntax() {
    #expect(FocusDomains.normalize(" HTTPS://YouTube.com/watch?v=test ") == "youtube.com")
    #expect(FocusDomains.normalize("www.reddit.com") == "www.reddit.com")
    for value in ["", "*.youtube.com", "localhost", "https://user:password@example.com", "example.com:80", "file://example.com", "bad..com", "-bad.com", "example.com^", "foo bar.com"] {
        #expect(FocusDomains.normalize(value) == nil)
    }
}

@Test func focusReleasesOnPauseResetCompletionAndStopwatch() {
    var timer = TimerEngine()
    timer.setDuration(10)
    func active(_ time: Double) -> Bool {
        BrowserFocusState(enabled: true, domains: ["youtube.com"], engine: timer, timerNow: time, wallNow: 100).active
    }
    #expect(!active(0))
    timer.start(at: 0)
    #expect(active(1))
    timer.pause(at: 2)
    #expect(!active(2))
    timer.start(at: 3)
    #expect(active(4))
    timer.update(at: 20)
    #expect(!active(20))
    timer.start(at: 21)
    timer.reset()
    #expect(!active(21))
    timer.setMode(.stopwatch)
    timer.start(at: 22)
    #expect(!active(23))
}

@Test func focusLeaseExpiresWithoutHeartbeatAndAtCountdownDeadline() {
    var timer = TimerEngine()
    timer.setDuration(10)
    timer.start(at: 0)
    let state = BrowserFocusState(enabled: true, domains: ["reddit.com"], engine: timer, timerNow: 1, wallNow: 100)
    #expect(state.isValid(at: 103))
    #expect(!state.isValid(at: 104))
    #expect(!state.isValid(at: 90))
    let nearEnd = BrowserFocusState(enabled: true, domains: ["reddit.com"], engine: timer, timerNow: 9, wallNow: 100)
    #expect(nearEnd.expiresAt == 101)
    let disabled = BrowserFocusState(enabled: false, domains: ["reddit.com"], engine: timer, timerNow: 1, wallNow: 100)
    #expect(!disabled.active)
    let empty = BrowserFocusState(enabled: true, domains: [], engine: timer, timerNow: 1, wallNow: 100)
    #expect(!empty.active)
}
