import AppKit
import Foundation

/// Only the bundled fresh-install settings declare onboarding incomplete.
/// Existing settings without this marker are legacy installations and are never prompted.
@MainActor
enum Onboarding {
    private static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/DaemonQuay/settings.json")
    }

    static var shouldPresent: Bool {
        guard let data = try? Data(contentsOf: settingsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = root["_daemonquay"] as? [String: Any] else { return false }
        return meta["onboardingCompleted"] as? Bool == false
    }

    /// Persist completion only on a user choice; preserve all unrelated JSON keys.
    @discardableResult
    static func complete() -> Bool {
        guard let data = try? Data(contentsOf: settingsURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var meta = root["_daemonquay"] as? [String: Any] else { return false }
        meta["onboardingCompleted"] = true
        root["_daemonquay"] = meta
        guard let output = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              (try? output.write(to: settingsURL, options: .atomic)) != nil else { return false }
        return true
    }

    static func present(manager: ServiceController) {
        guard shouldPresent else { return }
        let alert = NSAlert()
        alert.messageText = "Welcome to DaemonQuay"
        alert.informativeText = "Before starting services, please review their executable paths and startup settings."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        let choice = alert.runModal()
        // No service lifecycle action is triggered by this dialog.
        _ = complete()
        if choice == .alertFirstButtonReturn { WindowPresenter.shared.showSettings(manager) }
    }
}
