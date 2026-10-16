import SwiftUI
import AppKit

/// The selected tab visually continues into the document surface below it.
struct LogsView: View {
    @ObservedObject var manager: ServiceController
    @ObservedObject private var l10n = Localization.shared

    private var folder: URL {
        Paths.base.appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent(manager.selectedLogID, isDirectory: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(l10n.text("window.logs")).font(.title2.bold())
                Spacer()
                Picker(l10n.text("logs.select"), selection: $manager.selectedLogID) {
                    ForEach(manager.visibleServices) { plugin in
                        Label(plugin.name, systemImage: ModuleSymbol.resolved(plugin.symbol)).tag(plugin.id)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
                .onChange(of: manager.selectedLogID) { _, id in manager.loadLog(id) }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.text("logs.path"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(folder.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 12)
                Button {
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(folder)
                    } catch {
                        manager.lastError = error.localizedDescription
                    }
                } label: {
                    Label(l10n.text("logs.folder"), systemImage: "folder")
                }
                .help(folder.path)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    tab(.log, title: "Log")
                    tab(.error, title: "Error")
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
                .zIndex(2)

                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(nsColor: .textBackgroundColor))
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    ScrollView([.vertical, .horizontal]) {
                        Text(manager.logText)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(15)
                    }
                    .padding(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, -1)
                .zIndex(1)
            }

            HStack {
                Button {
                    manager.loadLog(manager.selectedLogID)
                } label: {
                    Label(l10n.text("logs.reload"), systemImage: "arrow.clockwise")
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 450)
        .onAppear { manager.loadLog(manager.selectedLogID) }
    }

    private func tab(_ channel: LogChannel, title: String) -> some View {
        let active = manager.selectedLogChannel == channel
        return Button {
            manager.loadLog(manager.selectedLogID, channel: channel)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Color.primary : Color.secondary)
                .padding(.horizontal, 23)
                .frame(height: 36)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 9, topTrailingRadius: 9)
                        .fill(active ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: 9, topTrailingRadius: 9)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                // Cover the document's top border under the selected tab, forming one sheet.
                .overlay(alignment: .bottom) {
                    if active {
                        Rectangle()
                            .fill(Color(nsColor: .textBackgroundColor))
                            .frame(height: 3)
                            .padding(.horizontal, 1)
                            .offset(y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .zIndex(active ? 3 : 0)
    }
}
