import SwiftUI
import AppKit

// Windows are created on demand. A MenuBarExtra by itself never creates a Dock window.
@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {
    static let shared = WindowPresenter()
    private var settingsWindow: NSWindow?
    private var logsWindow: NSWindow?

    func showSettings(_ manager: ServiceController) {
        if let window = settingsWindow { present(window); return }
        manager.refresh()
        let window = makeWindow("DaemonQuay " + Localization.shared.text("window.settings"), size: NSSize(width: 920, height: 680))
        window.contentViewController = NSHostingController(rootView: SettingsView(
            manager: manager,
            onClose: { [weak self] in self?.closeSettings() }
        ))
        settingsWindow = window
        present(window)
    }

    func showLogs(_ manager: ServiceController) {
        manager.loadLog(manager.selectedLogID)
        if logsWindow == nil {
            let window = makeWindow("DaemonQuay " + Localization.shared.text("window.logs"), size: NSSize(width: 990, height: 650))
            window.contentViewController = NSHostingController(rootView: LogsView(manager: manager))
            logsWindow = window
        }
        present(logsWindow!)
    }

    private func closeLogs() {
        logsWindow?.close()
        logsWindow = nil
    }

    private func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
    }

    private func makeWindow(_ title: String, size: NSSize) -> NSWindow {
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = title
        w.minSize = NSSize(width: min(size.width, 760), height: min(size.height, 560))
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        return w
    }

    private func present(_ window: NSWindow) {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow { settingsWindow = nil } // closing = cancel draft
        if window === logsWindow { logsWindow = nil }
    }
}

@MainActor
final class QuitCoordinator: NSObject, NSApplicationDelegate {
    var controller: ServiceController?
    private var statusMenu: StatusMenuController?
    private var systemShuttingDown = false
    private var approvedQuit = false
    private var stopping = false
    private var powerObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        guard SingleInstanceGuard.shared.acquire(onReopen: { [weak self] in
            self?.statusMenu?.showAlreadyRunningToast()
        }) else {
            // Do not create a second status icon or alter any launchd jobs.
            NSApplication.shared.terminate(nil)
            return
        }
        let manager = ServiceController()
        controller = manager
        let menu = StatusMenuController(manager: manager)
        menu.requestQuit = { NSApplication.shared.terminate(nil) }
        statusMenu = menu
        // Wait for the status item to be laid out by the menu bar before anchoring.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            if let manager = self?.controller, Onboarding.shouldPresent {
                Onboarding.present(manager: manager)
            } else {
                self?.statusMenu?.showStartupToast()
            }
        }
        powerObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.systemShuttingDown = true }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if systemShuttingDown || approvedQuit { return .terminateNow }
        guard let controller else { return .terminateNow }
        // Check actual launchd state, rather than a potentially stale UI toggle.
        if !controller.anyActiveNow() { return .terminateNow }
        if stopping { return .terminateCancel }
        let dialog = NSAlert()
        dialog.messageText = Localization.shared.text("alert.quit.title")
        dialog.informativeText = Localization.shared.text("alert.quit.message")
        dialog.alertStyle = .warning
        dialog.addButton(withTitle: Localization.shared.text("alert.quit.cancel"))
        dialog.addButton(withTitle: Localization.shared.text("alert.quit.stop"))
        if dialog.runModal() == .alertSecondButtonReturn {
            stopping = true
            controller.stopAllAndQuit { [weak self] success in
                guard let self else { return }
                self.stopping = false
                if success {
                    self.approvedQuit = true
                    NSApplication.shared.terminate(nil)
                } else {
                    let alert = NSAlert()
                    alert.messageText = Localization.shared.text("alert.stop.title")
                    alert.informativeText = controller.lastError ?? Localization.shared.text("alert.stop.message")
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
        return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct DaemonQuayApp: App {
    @NSApplicationDelegateAdaptor(QuitCoordinator.self) private var quitCoordinator

    // AppKit owns the menu-bar icon and all on-demand windows.
    // A settings-only Scene fulfils SwiftUI's App protocol without launching a window.
    var body: some Scene {
        Settings { EmptyView() }
    }
}
