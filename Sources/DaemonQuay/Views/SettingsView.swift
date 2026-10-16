import SwiftUI
import UniformTypeIdentifiers

/// Navigation and layout are independent of the module's settings schema.
struct SettingsView: View {
    @ObservedObject var manager: ServiceController
    @ObservedObject private var l10n = Localization.shared
    let onClose: () -> Void

    @State private var section = "general"
    @State private var draft: [String: String] = [:]
    @State private var saving = false
    @State private var showStartupHint = AppPreferences.showStartupHint()

    private var selectedModule: PluginDescriptor? {
        manager.services.first { $0.id == section }
    }
    private var editable: Bool {
        guard let module = selectedModule else { return false }
        return manager.statuses[module.id] == .stopped && !manager.busy.contains(module.id) && !saving
    }
    private var dirty: Bool {
        guard let module = selectedModule else { return false }
        let stored = manager.moduleValues(module.id)
        return module.settings.contains { field in
            let original = stored[field.key].map { String(describing: $0) } ?? ""
            return (draft[field.key] ?? "") != original
        }
    }
    private var currentLocale: String {
        if ["zh-Hant", "en"].contains(l10n.preference) { return l10n.preference }
        return "en"
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, minHeight: 540)
        .onAppear {
            manager.reloadModules()
            if section != "general" && section != "order" && selectedModule == nil { section = "general" }
            loadDraft()
            showStartupHint = AppPreferences.showStartupHint()
            manager.refresh()
        }
        .onChange(of: section) { _, _ in loadDraft() }
        .alert(l10n.text("settings.failed"), isPresented: Binding(
            get: { manager.lastError != nil },
            set: { if !$0 { manager.lastError = nil } }
        )) { Button(l10n.text("common.ok")) { manager.lastError = nil } }
        message: { Text(manager.lastError ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DaemonQuay")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 18)
            Text(l10n.text("settings.general"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            sidebarItem("general", title: l10n.text("settings.preferences"), symbol: "slider.horizontal.3")
            sidebarItem("order", title: l10n.text("settings.list"), symbol: "list.number")
            Divider().padding(.vertical, 6)
            Text(l10n.text("settings.modules"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(manager.services) { module in
                        sidebarItem(module.id, title: module.name, symbol: module.symbol)
                    }
                }
            }
            Spacer(minLength: 0)
            sidebarCredits
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebarCredits: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.bottom, 6)
            Text("DaemonQuay v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("© 2026 Y.C. Liu (ycliu0214)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Licensed under Apache License 2.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
    }

    private func sidebarItem(_ id: String, title: String, symbol: String) -> some View {
        Button {
            // Service drafts are intentionally discarded on navigation, just like Cancel.
            section = id
        } label: {
            HStack(spacing: 10) {
                ModuleSymbol.image(symbol).frame(width: 20)
                Text(title).lineLimit(1)
                Spacer(minLength: 3)
                if manager.hiddenIDs.contains(id) { Image(systemName: "eye.slash").foregroundStyle(.secondary) }
                if manager.busy.contains(id) { ProgressView().controlSize(.mini) }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(section == id ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            if section == "general" { general }
            else if section == "order" { order }
            else if let module = selectedModule { moduleForm(module) }
            else { Text(l10n.text("settings.noModules")).padding(24) }
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(l10n.text("settings.preferences"))
                .font(.title2.bold())
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 16) {
                        Text(l10n.text("settings.language"))
                        Spacer(minLength: 16)
                        Picker(l10n.text("settings.language"), selection: $l10n.preference) {
                            Text(l10n.text("lang.en")).tag("en")
                            Text(l10n.text("lang.zh")).tag("zh-Hant")
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                    Text(l10n.text("settings.languageNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)

                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 7) {
                    Toggle(l10n.text("settings.showStartupHint"), isOn: Binding(
                        get: { showStartupHint },
                        set: { newValue in
                            if AppPreferences.saveStartupHint(newValue) {
                                showStartupHint = newValue
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    Text(l10n.text("settings.showStartupHintNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 580, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }

    private var order: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l10n.text("settings.list")).font(.title2.bold())
            Text(l10n.text("settings.displayOrderHint"))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(manager.services) { module in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            ModuleSymbol.image(module.symbol).frame(width: 22)
                            Text(module.name)
                            Spacer(minLength: 4)
                            Toggle(l10n.text("settings.visible"), isOn: Binding(
                                get: { !manager.hiddenIDs.contains(module.id) },
                                set: { manager.setHidden(!$0, for: module.id) }
                            )).toggleStyle(.checkbox).fixedSize()
                            Button { manager.moveDisplayService(module.id, offset: -1) } label: { Image(systemName: "chevron.up") }
                                .disabled(manager.services.first?.id == module.id)
                                .help(l10n.text("settings.moveUp"))
                            Button { manager.moveDisplayService(module.id, offset: 1) } label: { Image(systemName: "chevron.down") }
                                .disabled(manager.services.last?.id == module.id)
                                .help(l10n.text("settings.moveDown"))
                        }
                        .padding(11)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                        .onDrag { NSItemProvider(object: module.id as NSString) }
                        .onDrop(of: [UTType.utf8PlainText], isTargeted: nil) { providers in
                            guard let provider = providers.first else { return false }
                            _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                                guard let id = item as? String else { return }
                                DispatchQueue.main.async { manager.moveDisplayService(id, before: module.id) }
                            }
                            return true
                        }
                    }
                }
            }
            Text(l10n.text("settings.visibilityHint"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func moduleForm(_ module: PluginDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ModuleSymbol.image(module.symbol).font(.title2).frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(module.name).font(.title2.bold())
                    Label(l10n.text(editable ? "settings.editable" : "settings.locked"),
                          systemImage: editable ? "checkmark.circle" : "lock")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            ScrollView {
                if module.settings.isEmpty {
                    Text(l10n.text("settings.noFields")).foregroundStyle(.secondary)
                } else {
                    Form {
                        ForEach(module.settings) { field in
                            TextField(field.label(currentLocale), text: binding(field.key))
                                .disabled(!editable)
                                .textFieldStyle(.roundedBorder)
                        }
                    }.formStyle(.grouped)
                }
            }
            Text(l10n.text("settings.note"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if saving { ProgressView().controlSize(.small) }
                if dirty { Text(l10n.text("settings.unsaved")).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button(l10n.text("common.cancel")) { loadDraft() }
                    .disabled(!dirty || saving)
                Button(l10n.text("settings.saveChanges")) {
                    saving = true
                    manager.save(module.id, values: draft) { success in
                        saving = false
                        if success { loadDraft() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!editable || !dirty || module.settings.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    private func loadDraft() {
        let stored = manager.moduleValues(section)
        var updated: [String: String] = [:]
        for field in selectedModule?.settings ?? [] {
            updated[field.key] = stored[field.key].map { String(describing: $0) } ?? ""
        }
        draft = updated
    }
    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { draft[key] ?? "" }, set: { draft[key] = $0 })
    }
}
