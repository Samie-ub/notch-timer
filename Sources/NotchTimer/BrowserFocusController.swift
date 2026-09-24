import AppKit
import SwiftUI
import TimerCore

struct BrowserFocusPointerStyle: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(isEnabled ? .link : nil)
        } else {
            content.onHover { hovering in
                if isEnabled && hovering { NSCursor.pointingHand.set() }
                else { NSCursor.arrow.set() }
            }
        }
    }
}

@MainActor
final class BrowserFocusController: ObservableObject {
    @Published var enabled = UserDefaults.standard.bool(forKey: "browserFocusEnabled") {
        didSet { UserDefaults.standard.set(enabled, forKey: "browserFocusEnabled"); changed?() }
    }
    @Published private(set) var domains = UserDefaults.standard.stringArray(forKey: "browserFocusDomains") ?? []
    @Published var message = ""
    var changed: (() -> Void)?
    private var lastState: BrowserFocusState?
    private var lastWrite: Double = 0

    func add(_ text: String) -> Bool {
        guard let domain = FocusDomains.normalize(text) else {
            message = "Enter a website such as youtube.com (no port or wildcard)."; return false
        }
        guard domains.count < 100 else { message = "You can add up to 100 websites."; return false }
        if !domains.contains(domain) { domains.append(domain); domains.sort(); saveDomains() }
        message = ""; return true
    }

    func remove(_ domain: String) { domains.removeAll { $0 == domain }; saveDomains() }
    private func saveDomains() {
        UserDefaults.standard.set(domains, forKey: "browserFocusDomains"); changed?()
    }

    func synchronize(engine: TimerEngine, now: Double) {
        let wallNow = Date().timeIntervalSince1970
        let state = BrowserFocusState(enabled: enabled, domains: domains, engine: engine,
                                      timerNow: now, wallNow: wallNow)
        guard state.active != lastState?.active || state.domains != lastState?.domains || wallNow - lastWrite >= 1 else { return }
        do {
            let url = BrowserFocusState.fileURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url, options: .atomic)
            lastState = state; lastWrite = wallNow
        } catch { message = "Cannot share the focus session: \(error.localizedDescription)" }
    }

    func stop() {
        // A missing file is an inactive session. Expiry is the fallback if removal fails.
        try? FileManager.default.removeItem(at: BrowserFocusState.fileURL)
    }

    func revealExtension() {
        guard let resources = Bundle.main.resourceURL,
              FileManager.default.fileExists(atPath: resources.appendingPathComponent("browser-extension/manifest.json").path) else {
            message = "Build and launch dist/settime.app to set up the extension."; return
        }
        NSWorkspace.shared.activateFileViewerSelecting([resources.appendingPathComponent("browser-extension")])
    }

    func connect(extensionID: String) {
        let id = extensionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.count == 32, id.utf8.allSatisfy({ (97...112).contains($0) }),
              let helper = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("BrowserFocusHost"),
              FileManager.default.isExecutableFile(atPath: helper.path) else {
            message = "Use the built app and paste the 32-letter extension ID from Chrome."; return
        }
        do {
            let folder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let manifest: [String: Any] = ["name": "com.local.notchtimer.focus", "description": "settime Browser Focus",
                "path": helper.path, "type": "stdio", "allowed_origins": ["chrome-extension://\(id)/"]]
            try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
                .write(to: folder.appendingPathComponent("com.local.notchtimer.focus.json"), options: .atomic)
            UserDefaults.standard.set(id, forKey: "browserFocusExtensionID")
            message = "Bridge installed. Open the Chrome extension to check its connection."
        } catch { message = "Setup failed: \(error.localizedDescription)" }
    }
}

struct BrowserFocusSettingsView: View {
    @ObservedObject var focus: BrowserFocusController
    @ObservedObject var model: TimerModel
    @State private var website = ""
    @State private var extensionID = UserDefaults.standard.string(forKey: "browserFocusExtensionID") ?? ""

    private var timerActive: Bool { model.engine.isRunning && model.engine.mode == .timer }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 22) {
                focusToggle
                VStack(alignment: .leading, spacing: 22) {
                    sessionCard
                    websitesSection
                    connectionSection
                    Text("Your pages stay open while focus is active.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .opacity(focus.enabled ? 1 : 0.42)
                .animation(.easeInOut(duration: 0.18), value: focus.enabled)
            }
            .frame(width: max(0, model.featurePanelSize.width - 44), alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(width: model.featurePanelSize.width)
        .scrollIndicators(.hidden)
    }

    private var focusToggle: some View {
        HStack(spacing: 14) {
            Image(systemName: "globe.badge.chevron.backward")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(nsColor: .systemGreen))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text("Browser Focus").font(.headline)
                Text("Block selected sites during focus")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Toggle("Enable Browser Focus", isOn: $focus.enabled)
                .labelsHidden().toggleStyle(.switch).tint(Color(nsColor: .systemGreen))
        }
        .padding(15)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeading("FOCUS SESSION", detail: model.engine.mode == .timer ? nil : "Timer mode")
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.time)
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .monospacedDigit().contentTransition(.numericText())
                    Text(timerActive ? "Focus is on" : model.engine.isFinished ? "Session complete" : "Ready when you are")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.toggle() } label: {
                    Label(timerActive ? "Pause" : "Start", systemImage: timerActive ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 15).padding(.vertical, 9)
                        .background(Color(nsColor: .systemGreen), in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .modifier(BrowserFocusPointerStyle())
                .disabled(model.engine.mode != .timer)
                .help(model.engine.mode == .timer ? (timerActive ? "Pause focus session" : "Start focus session") : "Switch to Timer mode")
                Button { model.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain).help("Reset timer")
                .modifier(BrowserFocusPointerStyle())
            }
            if model.engine.mode == .timer {
                ProgressView(value: model.progress)
                    .tint(timerActive ? Color(nsColor: .systemGreen) : .secondary)
                    .scaleEffect(x: 1, y: 0.75, anchor: .center)
            }
        }
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }

    private var websitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("WEBSITES", detail: "\(focus.domains.count)")
            HStack(spacing: 8) {
                TextField("Add a domain or URL", text: $website)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10))
                    .onSubmit { addWebsite() }
                Button { _ = pasteClipboard(into: $website) } label: {
                    Image(systemName: "doc.on.clipboard")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .modifier(BrowserFocusPointerStyle())
                .help("Paste a domain or URL")
                Button(action: addWebsite) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Color(nsColor: .systemGreen), in: Circle())
                }
                .buttonStyle(.plain)
                .modifier(BrowserFocusPointerStyle())
                .disabled(website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add website")
            }
            if focus.domains.isEmpty {
                ContentUnavailableView("No websites yet", systemImage: "globe", description: Text("Add a site you’d like to avoid."))
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(focus.domains.enumerated()), id: \.element) { index, domain in
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(domain).font(.system(size: 14)).lineLimit(1)
                            Spacer()
                            Button { focus.remove(domain) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary).font(.system(size: 16))
                            }
                            .buttonStyle(.plain).help("Remove \(domain)")
                            .modifier(BrowserFocusPointerStyle())
                        }
                        .padding(.horizontal, 11).padding(.vertical, 9)
                        if index < focus.domains.count - 1 {
                            Divider().overlay(.white.opacity(0.04)).padding(.leading, 41)
                        }
                    }
                }
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    @ViewBuilder private var connectionSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 11) {
                Text("Load the extension from Chrome’s Extensions page with Developer mode on.")
                Button { focus.revealExtension() } label: {
                    Label("Show Extension in Finder", systemImage: "folder")
                }
                .modifier(BrowserFocusPointerStyle())
                HStack(spacing: 8) {
                    TextField("Chrome extension ID", text: $extensionID)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 9))
                    Button("Paste", action: pasteExtensionID)
                        .buttonStyle(.bordered)
                        .modifier(BrowserFocusPointerStyle())
                }
                Button("Connect Chrome") { focus.connect(extensionID: extensionID) }
                    .buttonStyle(.borderedProminent).tint(Color(nsColor: .systemGreen))
                    .modifier(BrowserFocusPointerStyle())
                Text("Keep Notch Timer in its installed location. Reconnect if you move it.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .font(.callout).padding(.top, 10)
        } label: {
            Label("Chrome Extension Setup", systemImage: "puzzlepiece.extension")
                .font(.subheadline.weight(.medium))
        }
        .tint(.secondary)
        .padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
        if !focus.message.isEmpty {
            Label(focus.message, systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }

    private func sectionHeading(_ title: String, detail: String? = nil) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold)).tracking(0.7).foregroundStyle(.secondary)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.tertiary) }
        }
    }

    private func addWebsite() { if focus.add(website) { website = "" } }

    private func pasteExtensionID() {
        guard pasteClipboard(into: $extensionID) else { return }
        focus.message = "Extension ID pasted. Click Connect Chrome to finish setup."
    }

    @discardableResult
    private func pasteClipboard(into field: Binding<String>) -> Bool {
        guard let clipboard = NSPasteboard.general.string(forType: .string),
              !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            focus.message = "The clipboard does not contain text. Copy a value first."
            return false
        }
        field.wrappedValue = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }
}
