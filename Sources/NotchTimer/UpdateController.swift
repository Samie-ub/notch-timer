import AppKit
import Sparkle

/// Owns Sparkle for the lifetime of the app. Plain `swift run` has no update bundle.
@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate, NSMenuItemValidation {
    private let prepareForRestart: () -> Void
    private let cancelRestart: () -> Void
    private var controller: SPUStandardUpdaterController?

    init(prepareForRestart: @escaping () -> Void, cancelRestart: @escaping () -> Void) {
        self.prepareForRestart = prepareForRestart
        self.cancelRestart = cancelRestart
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
        return controller?.updater.canCheckForUpdates == true
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        prepareForRestart()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        cancelRestart()
    }
}
