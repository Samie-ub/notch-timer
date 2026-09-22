import AppKit
import SwiftUI

enum NotchLayout {
    static let size = NSSize(width: 100, height: 22)
    static let topSpacing: CGFloat = 4
    static let expandedSize = NSSize(width: 360, height: 44)

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.30, dampingFraction: 1)
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // The compact pill intentionally occupies the menu bar's screen area.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .canJoinAllApplications]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TimerModel()
    private var notch: FloatingPanel!
    private var transitionID = 0
    private var statusItem: NSStatusItem!
    private var isNotchHovered = false
    private var hoverCloseTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        notch = FloatingPanel(size: NotchLayout.size)
        notch.hasShadow = false
        let content = NSHostingView(rootView: NotchView(
            model: model,
            openControls: { [weak self] in self?.showSettings() },
            closeControls: { [weak self] in self?.closeSettings() },
            hoverChanged: { [weak self] hovering in self?.hoverChanged(hovering) }
        ))
        content.sizingOptions = []
        notch.contentView = content
        placeNotch()
        notch.orderFrontRegardless()
        configureMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wokeUp), name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Notch Timer")
        let menu = NSMenu()
        menu.addItem(withTitle: "Notch Timer", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: "Show Controls", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        let toggleItem = menu.addItem(withTitle: "Start / Pause", action: #selector(toggleTimer), keyEquivalent: "")
        toggleItem.target = self
        let resetItem = menu.addItem(withTitle: "Reset", action: #selector(resetTimer), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Notch Timer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func placeNotch(size: NSSize? = nil) {
        // The first screen owns the menu bar; don't jump between displays as focus changes.
        guard let screen = NSScreen.screens.first else { return }
        // Leave space below the top edge, or below a physical camera cutout.
        let size = size ?? notch.frame.size
        let y = screen.frame.maxY - screen.safeAreaInsets.top - NotchLayout.topSpacing - size.height
        notch.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: y,
                              width: size.width, height: size.height), display: true)
    }

    @objc private func showSettings() {
        expandControls(activate: true)
        if !isNotchHovered { scheduleHoverClose() }
    }

    private func hoverChanged(_ hovering: Bool) {
        isNotchHovered = hovering
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
        if hovering {
            // Hover should reveal controls without stealing keyboard focus.
            expandControls(activate: false)
        } else {
            scheduleHoverClose()
        }
    }

    private func scheduleHoverClose() {
        hoverCloseTask?.cancel()
        hoverCloseTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard let self, !self.isNotchHovered else { return }
            self.hoverCloseTask = nil
            self.closeSettings()
        }
    }

    private func expandControls(activate: Bool) {
        if activate { notch.makeKeyAndOrderFront(nil) }
        guard model.notchScreen == .compact else { return }
        transitionID += 1
        // Give the spring room to draw before expanding the visible capsule.
        placeNotch(size: NotchLayout.expandedSize)
        withAnimation(NotchLayout.animation(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)) {
            model.notchScreen = .controls
        }
    }

    private func closeSettings() {
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
        guard model.notchScreen != .compact else { return }
        transitionID += 1
        let closingTransition = transitionID
        withAnimation(NotchLayout.animation(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion),
                      completionCriteria: .removed) {
            model.notchScreen = .compact
        } completion: { [weak self] in
            guard let self, self.transitionID == closingTransition, self.model.notchScreen == .compact else { return }
            // Shrink the native hit area only after the visible capsule finishes closing.
            self.placeNotch(size: NotchLayout.size)
            self.notch.resignKey()
        }
    }

    @objc private func toggleTimer() { model.toggle() }
    @objc private func resetTimer() { model.reset() }
    @objc private func screenChanged() { placeNotch() }
    @objc private func wokeUp() { model.tick(); placeNotch(); notch.orderFrontRegardless() }

    func applicationWillTerminate(_ notification: Notification) {
        hoverCloseTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

@main
struct NotchTimerApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
