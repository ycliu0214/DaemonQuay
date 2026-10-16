import Foundation
import Combine

@MainActor
final class ServiceController: ObservableObject {
    @Published private(set) var services: [PluginDescriptor] = []
    @Published private(set) var issues: [PluginIssue] = []
    @Published private(set) var statuses: [String: ServiceStatus] = [:]
    @Published private(set) var busy: Set<String> = []
    @Published var message = ""
    @Published var logText = ""
    @Published var selectedLogChannel = LogChannel.log
    @Published var selectedLogID = ""
    @Published var lastError: String?

    var onStatusChange: (() -> Void)?
    @Published private(set) var hiddenIDs: Set<String> = ServiceVisibility.read()
    var visibleServices: [PluginDescriptor] { services.filter { !hiddenIDs.contains($0.id) } }

    func setHidden(_ hidden: Bool, for id: String) {
        guard services.contains(where: { $0.id == id }) else { return }
        if hidden {
            guard !busy.contains(id), statuses[id] == .stopped,
                  let plugin = services.first(where: { $0.id == id }),
                  PluginRuntime.invoke(plugin, action: "status").code == 1 else {
                lastError = Localization.shared.text("settings.hideRunning")
                return
            }
        }
        var next = hiddenIDs
        if hidden { next.insert(id) } else { next.remove(id) }
        do {
            try ServiceVisibility.save(next)
            hiddenIDs = next
            if hidden && selectedLogID == id { selectedLogID = visibleServices.first?.id ?? "" }
            onStatusChange?()
        } catch { lastError = "Cannot save service visibility: \(error.localizedDescription)" }
    }
    private var polling: Timer?
    private var refreshInProgress = false

    init() {
        reloadModules()
        refresh()
        polling = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func reloadModules() {
        let result = PluginRegistry.discover()
        issues = result.issues
        hiddenIDs = ServiceVisibility.read()
        services = ServiceDisplayOrder.ordered(result.modules.filter { PluginRegistry.enabledIDs().contains($0.id) })
        if !visibleServices.contains(where: { $0.id == selectedLogID }) { selectedLogID = visibleServices.first?.id ?? "" }
        onStatusChange?()
    }

    /// Display order is independent of module lifecycle stopOrder.
    func moveDisplayService(_ draggedID: String, before targetID: String) {
        guard draggedID != targetID,
              let source = services.firstIndex(where: { $0.id == draggedID }),
              let destination = services.firstIndex(where: { $0.id == targetID }) else { return }
        let moved = services.remove(at: source)
        let targetIndex = services.firstIndex(where: { $0.id == targetID }) ?? destination
        services.insert(moved, at: targetIndex)
        persistDisplayOrder()
    }

    func moveDisplayService(_ id: String, offset: Int) {
        guard let source = services.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard services.indices.contains(destination) else { return }
        services.swapAt(source, destination)
        persistDisplayOrder()
    }

    private func persistDisplayOrder() {
        do {
            try ServiceDisplayOrder.save(services.map(\.id))
            onStatusChange?()
        } catch {
            lastError = "Could not save service display order: \(error.localizedDescription)"
        }
    }

    private func module(_ id: String) -> PluginDescriptor? { services.first { $0.id == id } }
    func name(_ id: String) -> String { module(id)?.name ?? id }

    func refresh() {
        guard !refreshInProgress else { return }
        refreshInProgress = true
        let current = services
        Task.detached {
            let checks = current.map { ($0.id, PluginRuntime.invoke($0, action: "status")) }
            await MainActor.run {
                for (id, result) in checks {
                    self.statuses[id] = switch result.code {
                    case 0: .running
                    case 1: .stopped
                    case 3: .external
                    default: .error
                    }
                }
                self.refreshInProgress = false
                self.onStatusChange?()
            }
        }
    }

    var anyActive: Bool {
        services.contains { busy.contains($0.id) || (statuses[$0.id] ?? .error).isActive }
    }
    func anyActiveNow() -> Bool {
        if !busy.isEmpty { return true }
        return services.contains { PluginRuntime.invoke($0, action: "status").code != 1 }
    }

    func setRunning(_ on: Bool, for id: String) {
        guard let plugin = module(id), !busy.contains(id) else { return }
        guard on ? statuses[id] == .stopped : statuses[id] == .running else { return }
        busy.insert(id)
        onStatusChange?()
        message = on ? "Starting \(plugin.name)…" : "Stopping \(plugin.name)…"
        Task.detached {
            let result = PluginRuntime.invoke(plugin, action: on ? "start" : "stop")
            await MainActor.run {
                self.busy.remove(id)
                self.message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if result.code != 0 { self.lastError = self.message }
                self.refresh()
                self.onStatusChange?()
            }
        }
    }

    func moduleValues(_ id: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: Paths.config),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return root[id] as? [String: Any] ?? [:]
    }

    // Preserve all other modules' configurations and unknown keys verbatim as JSON values.
    func save(_ id: String, values: [String: String], completion: @escaping (Bool) -> Void) {
        guard let plugin = module(id), statuses[id] == .stopped, !busy.contains(id) else {
            lastError = "Please stop the service before editing settings."
            completion(false)
            return
        }
        do {
            var root: [String: Any] = [:]
            if let data = try? Data(contentsOf: Paths.config) {
                root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            }
            var current = root[id] as? [String: Any] ?? [:]
            for field in plugin.settings {
                guard let raw = values[field.key] else { continue }
                if field.type == "integer" {
                    guard let number = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                        throw PluginError.invalid("Invalid integer: \(field.key)")
                    }
                    current[field.key] = number
                } else {
                    current[field.key] = raw
                }
            }
            root[id] = current
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            let old = try? Data(contentsOf: Paths.config)
            // Persist before module validation, then restore the exact old bytes on failure.
            try data.write(to: Paths.config, options: .atomic)
            busy.insert(id)
            Task.detached {
                let result = plugin.supportsValidate
                    ? PluginRuntime.invoke(plugin, action: "validate")
                    : CommandResult(code: 0, output: "Saved")
                await MainActor.run {
                    self.busy.remove(id)
                    if result.code == 0 {
                        self.message = "\(plugin.name): settings saved; start manually to apply."
                        completion(true)
                    } else {
                        if let old {
                            try? old.write(to: Paths.config, options: .atomic)
                        } else {
                            try? FileManager.default.removeItem(at: Paths.config)
                        }
                        self.lastError = "Validation failed: \(result.output)"
                        completion(false)
                    }
                    self.refresh()
                }
            }
        } catch {
            lastError = "Could not save settings: \(error.localizedDescription)"
            completion(false)
        }
    }

    func loadLog(_ id: String, channel: LogChannel? = nil) {
        guard !id.isEmpty else { logText = ""; return }
        selectedLogID = id
        if let channel { selectedLogChannel = channel }
        let url = Paths.log(id, error: selectedLogChannel == .error)
        let legacy = Paths.legacyLog(id, error: selectedLogChannel == .error)
        let selected = FileManager.default.fileExists(atPath: url.path) ? url : legacy
        do {
            logText = try LogTailReader.read(selected)
        } catch {
            logText = Localization.shared.text("logs.none")
        }
    }

    func stopAllAndQuit(_ completion: @escaping (Bool) -> Void) {
        if !busy.isEmpty { lastError = "A service operation is in progress."; completion(false); return }
        let all = services.sorted { $0.stopOrder < $1.stopOrder }
        Task.detached {
            for plugin in all {
                let current = PluginRuntime.invoke(plugin, action: "status")
                if current.code == 3 || (current.code != 0 && current.code != 1) {
                    await MainActor.run {
                        self.lastError = "Cannot safely determine \(plugin.name) state: \(current.output)"
                        self.refresh(); completion(false)
                    }
                    return
                }
                if current.code == 0 {
                    let result = PluginRuntime.invoke(plugin, action: "stop")
                    if result.code != 0 {
                        await MainActor.run {
                            self.lastError = "Cannot gracefully stop \(plugin.name): \(result.output)"
                            self.refresh(); completion(false)
                        }
                        return
                    }
                }
            }
            await MainActor.run { self.refresh(); completion(true) }
        }
    }
}
