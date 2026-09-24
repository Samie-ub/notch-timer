import AppKit
import SwiftUI
import TimerCore

enum NotchLayout {
    static let size = NSSize(width: 100, height: 22)
    static let topSpacing: CGFloat = 4
    static let expandedSize = NSSize(width: 360, height: 44)

    static let featureSize = NSSize(width: 360, height: 560)
    static func size(for screen: NotchScreen, featureSize: CGSize) -> CGSize {
        screen.isFeaturePanel ? featureSize : (screen == .compact ? size : expandedSize)
    }

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
    private var isPreparingExpansion = false
    private var statusItem: NSStatusItem!
    private var isNotchHovered = false
    private var ignoreHoverUntilExit = false
    private var hoverCloseTask: Task<Void, Never>?
    private var positionAnchor: CGPoint?
    private var dragStart: (mouse: CGPoint, anchor: CGPoint)?
    private var isDragging: Bool { dragStart != nil }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        if let x = defaults.object(forKey: "notchPositionX") as? Double,
           let y = defaults.object(forKey: "notchPositionY") as? Double,
           x.isFinite, y.isFinite {
            positionAnchor = CGPoint(x: x, y: y)
        }
        notch = FloatingPanel(size: NotchLayout.size)
        notch.hasShadow = false
        let content = NSHostingView(rootView: NotchView(
            model: model,
            openControls: { [weak self] in self?.showSettings() },
            closeControls: { [weak self] in self?.closeSettings() },
            openBrowserFocus: { [weak self] in self?.showBrowserFocus() },
            hoverChanged: { [weak self] hovering in self?.hoverChanged(hovering) },
            dragChanged: { [weak self] point in self?.dragChanged(point) },
            dragEnded: { [weak self] in self?.dragEnded() }
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
        // Text fields live in a floating non-activating panel. Provide the
        // standard responder-chain Paste action so Command-V reaches them.
        let mainMenu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "settime")
        let menu = NSMenu()
        menu.addItem(withTitle: "settime", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: "Show Controls", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        let focusItem = menu.addItem(withTitle: "Browser Focus…", action: #selector(showBrowserFocus), keyEquivalent: "")
        focusItem.target = self
        let toggleItem = menu.addItem(withTitle: "Start / Pause", action: #selector(toggleTimer), keyEquivalent: "")
        toggleItem.target = self
        let resetItem = menu.addItem(withTitle: "Reset", action: #selector(resetTimer), keyEquivalent: "")
        resetItem.target = self
        let positionItem = menu.addItem(withTitle: "Reset Notch Position", action: #selector(resetPosition), keyEquivalent: "")
        positionItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit settime", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func showBrowserFocus() { transition(to: .browserFocus, activate: true) }

    private func placeNotch(size: NSSize? = nil, display: Bool = true, on targetScreen: NSScreen? = nil) {
        guard let primary = NSScreen.screens.first else { return }
        let anchor = positionAnchor ?? CGPoint(x: primary.frame.midX,
                                               y: primary.frame.maxY - primary.safeAreaInsets.top - NotchLayout.topSpacing)
        // Recover gracefully if a saved display has been disconnected or rearranged.
        let screen = targetScreen ?? NSScreen.screens.min { distance(anchor, to: $0.frame) < distance(anchor, to: $1.frame) } ?? primary
        var bounds = screen.frame.insetBy(dx: 4, dy: 4)
        bounds.size.height = max(0, screen.frame.maxY - screen.safeAreaInsets.top - NotchLayout.topSpacing - bounds.minY)
        let size = size ?? notch.frame.size
        notch.setFrame(NotchPlacement.frame(size: size, anchor: anchor, bounds: bounds), display: display)
    }

    private func distance(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    private func dragChanged(_ mouse: CGPoint) {
        if dragStart == nil {
            hoverCloseTask?.cancel()
            hoverCloseTask = nil
            transitionID += 1
            isPreparingExpansion = false
            dragStart = (mouse, CGPoint(x: notch.frame.midX, y: notch.frame.maxY))
        }
        guard let start = dragStart else { return }
        positionAnchor = CGPoint(x: start.anchor.x + mouse.x - start.mouse.x,
                                 y: start.anchor.y + mouse.y - start.mouse.y)
        placeNotch(on: NSScreen.screens.first { $0.frame.contains(mouse) })
    }

    private func dragEnded() {
        guard isDragging else { return }
        // Persist the actual clamped position, not a point beyond a display edge.
        let anchor = CGPoint(x: notch.frame.midX, y: notch.frame.maxY)
        positionAnchor = anchor
        dragStart = nil
        UserDefaults.standard.set(anchor.x, forKey: "notchPositionX")
        UserDefaults.standard.set(anchor.y, forKey: "notchPositionY")
        placeNotch(size: NotchLayout.size(for: model.notchScreen, featureSize: model.featurePanelSize))
        hoverChanged(notch.frame.contains(NSEvent.mouseLocation))
    }

    @objc private func resetPosition() {
        dragStart = nil
        positionAnchor = nil
        UserDefaults.standard.removeObject(forKey: "notchPositionX")
        UserDefaults.standard.removeObject(forKey: "notchPositionY")
        placeNotch()
        hoverChanged(notch.frame.contains(NSEvent.mouseLocation))
    }

    @objc private func showSettings() {
        expandControls(activate: true)
        if !isNotchHovered { scheduleHoverClose() }
    }

    private func hoverChanged(_ hovering: Bool) {
        isNotchHovered = hovering
        if !hovering { ignoreHoverUntilExit = false }
        guard !isDragging else { return }
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
        if hovering {
            guard !ignoreHoverUntilExit else { return }
            // Hover should reveal controls without stealing keyboard focus.
            expandControls(activate: false)
        } else {
            scheduleHoverClose()
        }
    }

    private func scheduleHoverClose() {
        guard !isDragging, !model.notchScreen.isFeaturePanel else { return }
        hoverCloseTask?.cancel()
        hoverCloseTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard let self, !self.isNotchHovered, !self.isDragging,
                  !self.model.notchScreen.isFeaturePanel else { return }
            self.hoverCloseTask = nil
            self.closeSettings()
        }
    }

    private func expandControls(activate: Bool) {
        guard model.notchScreen == .compact, !isPreparingExpansion else { return }
        transition(to: .controls, activate: activate)
    }

    private func closeSettings() {
        ignoreHoverUntilExit = isNotchHovered
        transition(to: .compact)
    }

    // Shared presentation path for any future feature that needs a larger body.
    // The native window grows first; SwiftUI animates from the same top anchor.
    private func transition(to screen: NotchScreen, activate: Bool = false) {
        guard !isDragging else { return }
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
        transitionID += 1
        let currentTransition = transitionID
        isPreparingExpansion = true
        notch.level = screen.isFeaturePanel ? .floating : .statusBar
        if screen.isFeaturePanel {
            let bounds = notch.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            model.featurePanelSize = CGSize(
                width: min(NotchLayout.featureSize.width, (bounds?.width ?? 508) - 8),
                height: min(NotchLayout.featureSize.height, (bounds?.height ?? 568) - 8))
        }
        let targetSize = NotchLayout.size(for: screen, featureSize: model.featurePanelSize)
        let envelope = CGSize(width: max(notch.frame.width, targetSize.width),
                              height: max(notch.frame.height, targetSize.height))
        var preparation = Transaction(animation: nil)
        preparation.disablesAnimations = true
        withTransaction(preparation) {
            placeNotch(size: envelope, display: false)
        }
        if activate { notch.makeKeyAndOrderFront(nil) }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.transitionID == currentTransition else { return }
            self.isPreparingExpansion = false
            withAnimation(NotchLayout.animation(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion),
                          completionCriteria: .removed) {
                self.model.notchScreen = screen
            } completion: { [weak self] in
                guard let self, self.transitionID == currentTransition else { return }
                self.placeNotch(size: targetSize)
                if screen == .compact { self.notch.resignKey() }
            }
        }
    }

    @objc private func toggleTimer() { model.toggle() }
    @objc private func resetTimer() { model.reset() }
    @objc private func screenChanged() { placeNotch() }
    @objc private func wokeUp() { model.tick(); placeNotch(); notch.orderFrontRegardless() }

    func applicationWillTerminate(_ notification: Notification) {
        model.browserFocus.stop()
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
