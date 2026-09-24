import AppKit
import Sparkle

/// Owns Sparkle for the lifetime of the app. Plain `swift run` has no update bundle.
@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate, NSMenuItemValidation {
    private let hasSession: () -> Bool
    private var controller: SPUStandardUpdaterController?
    private var deferredInstall: Task<Void, Never>?
    private var restartingForUpdate = false

    init(hasSession: @escaping () -> Bool) {
        self.hasSession = hasSession
        super.init()
        guard Bundle.main.bundleURL.pathExtension == "app",
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !key.isEmpty else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller?.checkForUpdates(sender)
    }

    @objc func toggleAutomaticChecks(_ sender: NSMenuItem) {
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates.toggle()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleAutomaticChecks(_:)) {
            item.state = controller?.updater.automaticallyChecksForUpdates == true ? .on : .off
            return controller != nil
        }
        item.title = deferredInstall == nil ? "Check for Updates…" : "Update Waiting for Session to End"
        if deferredInstall != nil { return false }
        return controller?.updater.canCheckForUpdates == true
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard hasSession() else { return false }
        deferredInstall?.cancel()
        deferredInstall = Task { @MainActor [weak self] in
            while self?.hasSession() == true {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            guard self != nil, !Task.isCancelled else { return }
            self?.deferredInstall = nil
            installHandler()
        }
        return true
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        restartingForUpdate = true
    }

    /// Final guard if a new session starts after the deferred install was released.
    func shouldCancelRestart() -> Bool {
        defer { restartingForUpdate = false }
        return restartingForUpdate && hasSession()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        deferredInstall?.cancel()
        deferredInstall = nil
        restartingForUpdate = false
    }
}
