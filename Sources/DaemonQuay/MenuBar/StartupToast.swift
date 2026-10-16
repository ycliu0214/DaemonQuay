import AppKit
import SwiftUI

/// Non-activating message with a pointer aligned to the actual menu-bar icon.
@MainActor
final class StartupToast {
    enum Message { case started, alreadyRunning }
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var globalClick: Any?
    private var localClick: Any?

    func show(under button: NSStatusBarButton, message: Message = .started, duration: TimeInterval = 3) {
        hide()
        guard let window = button.window else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = window.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let width: CGFloat = 268
        let height: CGFloat = 88
        let gap: CGFloat = 2
        let x = min(max(anchor.midX - width / 2, visible.minX + 8), visible.maxX - width - 8)
        let y = max(visible.minY + 8, anchor.minY - height - gap)
        // Clamping the panel must not move the pointer away from the real status icon.
        let pointerX = min(max(anchor.midX - x, 19), width - 19)

        let p = NSPanel(contentRect: NSRect(x: x, y: y, width: width, height: height),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: StartupToastView(pointerX: pointerX, message: message))
        panel = p
        p.orderFrontRegardless()

        globalClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        localClick = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in self?.hide() }
            return event
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        if let token = globalClick { NSEvent.removeMonitor(token); globalClick = nil }
        if let token = localClick { NSEvent.removeMonitor(token); localClick = nil }
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}

private struct ToastPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct StartupToastView: View {
    let pointerX: CGFloat
    let message: StartupToast.Message
    private let bubble = Color(nsColor: .windowBackgroundColor)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ToastPointer()
                .fill(bubble)
                .frame(width: 18, height: 9)
                .offset(x: pointerX - 9, y: 1)
                .zIndex(2)

            HStack(alignment: .center, spacing: 9) {
                Image(systemName: message == .started ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(message == .started ? Color.green : Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Localization.shared.text(message == .started ? "toast.title" : "toast.alreadyRunning.title"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(Localization.shared.text(message == .started ? "toast.subtitle" : "toast.alreadyRunning.subtitle"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 268, height: 76)
            .background(bubble, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)))
            .offset(y: 8)
        }
        .frame(width: 268, height: 88, alignment: .topLeading)
    }
}
