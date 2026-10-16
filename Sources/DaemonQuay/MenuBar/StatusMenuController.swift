import AppKit

/// Menu-bar-only control surface. Service state is supplied by ServiceController.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let manager: ServiceController
    private let statusItem: NSStatusItem
    private let toast = StartupToast()
    private let menu = NSMenu()
    private var menuOpen = false
    var requestQuit: (() -> Void)?

    init(manager: ServiceController) {
        self.manager = manager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            // Size the image BEFORE assigning it. A variable-width status item can
            // otherwise preserve the original (large) bitmap's intrinsic width.
            let icon = Bundle.main.url(forResource: "MenuBarTemplate", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
                ?? NSImage(systemSymbolName: "server.rack", accessibilityDescription: "DaemonQuay")
            if let icon {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            }
            button.imagePosition = .imageOnly
            button.toolTip = "DaemonQuay"
        }
        manager.onStatusChange = { [weak self] in
            guard let self, self.menuOpen else { return }
            self.rebuildMenu()
        }
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Called when a duplicate launch notifies the running instance.
    /// Never opens the menu or changes a managed service.
    func showAlreadyRunningToast() {
        guard let button = statusItem.button else { return }
        if menuOpen { return }
        toast.show(under: button, message: .alreadyRunning)
    }

    func showStartupToast() {
        guard let button = statusItem.button else { return }
        guard AppPreferences.showStartupHint() else { return }
        toast.show(under: button)
    }

    func menuWillOpen(_ menu: NSMenu) {
        toast.hide()
        menuOpen = true
        rebuildMenu()
        manager.refresh()
    }

    func menuDidClose(_ menu: NSMenu) { menuOpen = false }

    private func tr(_ key: String) -> String { Localization.shared.text(key) }

    // Use a small, muted status dot while retaining native NSMenuItem behavior.
    // NSAttributedString draws the indicator independently from the main menu font.
    private let indicatorPointSize: CGFloat = 8

    private func statusColor(_ status: ServiceStatus, busy: Bool) -> NSColor {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        func color(_ light: (CGFloat, CGFloat, CGFloat),
                   _ darkColor: (CGFloat, CGFloat, CGFloat)) -> NSColor {
            let rgb = dark ? darkColor : light
            return NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
        // Restrained contrast in both light and dark menu appearances.
        if busy { return color((0.69, 0.46, 0.24), (0.85, 0.65, 0.39)) }
        switch status {
        case .running:  return color((0.29, 0.59, 0.42), (0.43, 0.75, 0.55))
        case .stopped:  return color((0.56, 0.59, 0.63), (0.65, 0.68, 0.72))
        case .external: return color((0.69, 0.46, 0.24), (0.85, 0.65, 0.39))
        case .error:    return color((0.74, 0.38, 0.42), (0.88, 0.53, 0.55))
        }
    }

    // Measure the visible service names at menu construction time. A capped name
    // column prevents a third-party module with an extreme name from widening
    // the menu indefinitely. The full name remains in the item's tooltip.
    private let maximumNameWidth: CGFloat = 280
    private let serviceColumnGap: CGFloat = 28
    private let menuHorizontalAllowance: CGFloat = 48

    private func renderedServiceName(_ name: String, font: NSFont) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        func width(_ value: String) -> CGFloat {
            (value as NSString).size(withAttributes: attributes).width
        }
        if width(name) <= maximumNameWidth { return name }
        var shortened = name
        while !shortened.isEmpty && width(shortened + "…") > maximumNameWidth {
            shortened.removeLast()
        }
        return shortened + "…"
    }

    private func serviceTitle(_ name: String, action: String,
                              status: ServiceStatus, busy: Bool,
                              actionTab: CGFloat, font: NSFont) -> NSAttributedString {
        let title = NSMutableAttributedString(string: "●  \(name)\t\(action)")
        let paragraph = NSMutableParagraphStyle()
        // A right-aligned tab positions Start and Stop at the same trailing edge
        // without fragile space-padding or a custom NSMenuItem.view.
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: actionTab)]
        paragraph.defaultTabInterval = 0
        title.addAttributes([.font: font, .paragraphStyle: paragraph],
                            range: NSRange(location: 0, length: title.length))
        title.addAttributes([.foregroundColor: statusColor(status, busy: busy),
                             .font: NSFont.systemFont(ofSize: indicatorPointSize, weight: .medium),
                             .baselineOffset: 1.0],
                            range: NSRange(location: 0, length: 1))
        return title
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let header = NSMenuItem(title: "DaemonQuay", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        let visible = manager.visibleServices
        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let labelWidth = visible.map {
            (renderedServiceName($0.name, font: font) as NSString)
                .size(withAttributes: attributes).width
        }.max() ?? 0
        let actionWidth = [tr("menu.start"), tr("menu.stop")].map {
            ($0 as NSString).size(withAttributes: attributes).width
        }.max() ?? 0
        let indicatorWidth = ("●" as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: indicatorPointSize, weight: .medium)
        ]).width + ("  " as NSString).size(withAttributes: attributes).width
        let actionTab = ceil(indicatorWidth + labelWidth + serviceColumnGap + actionWidth)
        // Do not allow a previous, wider menu state to survive after hiding a
        // module. NSMenu may also grow to fit its ordinary Settings/Logs rows.
        menu.minimumWidth = ceil(actionTab + menuHorizontalAllowance)

        for plugin in visible {
            let status = manager.statuses[plugin.id] ?? .error
            let busy = manager.busy.contains(plugin.id)
            let start = status == .stopped
            let action = tr(start ? "menu.start" : "menu.stop")
            let displayName = renderedServiceName(plugin.name, font: font)
            let item = NSMenuItem(
                title: "\(displayName)  \(action)",
                action: #selector(toggleService(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = plugin.id
            item.attributedTitle = serviceTitle(displayName,
                action: action, status: status, busy: busy,
                actionTab: actionTab, font: font)
            item.toolTip = "\(plugin.name) · \(tr(status.localizationKey))"
            item.isEnabled = !busy && (status == .running || status == .stopped)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        add(tr("menu.settings"), "gearshape", #selector(openSettings))
        add(tr("menu.logs"), "doc.text", #selector(openLogs))
        add(tr("common.refresh"), "arrow.clockwise", #selector(refresh))
        menu.addItem(.separator())
        add(tr("menu.quit"), "power", #selector(quit))
    }

    private func add(_ title: String, _ symbol: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        menu.addItem(item)
    }

    @objc private func toggleService(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String,
              manager.services.contains(where: { $0.id == raw }) else { return }
        let status = manager.statuses[raw] ?? .error
        manager.setRunning(status == .stopped, for: raw)
    }
    @objc private func openSettings() { WindowPresenter.shared.showSettings(manager) }
    @objc private func openLogs() { WindowPresenter.shared.showLogs(manager) }
    @objc private func refresh() { manager.refresh() }
    @objc private func quit() { requestQuit?() }
}
