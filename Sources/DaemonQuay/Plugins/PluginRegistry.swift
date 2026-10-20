import Foundation

/// Identical discovery/validation for the shipped oMLX/Caddy modules and new modules.
/// No service-specific Swift registry, special start/stop/status handling or name exclusions.
enum PluginRegistry {
    static var userRoot: URL { Paths.base.appendingPathComponent("modules", isDirectory: true) }
    static var bundleRoot: URL {
        Bundle.main.resourceURL!.appendingPathComponent("Modules", isDirectory: true)
    }
    private static var enabledFile: URL { Paths.base.appendingPathComponent("enabled-modules.json") }
    private static let idPattern = "^[a-z][a-z0-9-]{1,39}$"

    static func enabledIDs() -> Set<String> {
        guard let data = try? Data(contentsOf: enabledFile),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            // Compatibility when upgrading without running install.sh.
            return ["omlx", "caddy"]
        }
        return Set(ids)
    }
    static func saveEnabled(_ ids: Set<String>) throws {
        try FileManager.default.createDirectory(at: Paths.base, withIntermediateDirectories: true)
        try JSONEncoder().encode(ids.sorted()).write(to: enabledFile, options: .atomic)
    }

    static func discover() -> (modules: [PluginDescriptor], issues: [PluginIssue]) {
        let fm = FileManager.default
        var found: [PluginDescriptor] = []
        var issues: [PluginIssue] = []
        var used = Set<String>()
        for root in [bundleRoot, userRoot] {
            guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for dir in dirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                let folder = dir.lastPathComponent
                do {
                    let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: dir.appendingPathComponent("module.json")))
                    guard manifest.apiVersion == 1 else { throw PluginError.invalid("Unsupported module API version") }
                    guard manifest.id == folder,
                          manifest.id.range(of: idPattern, options: .regularExpression) != nil else {
                        throw PluginError.invalid("Module ID must match its folder and contain lowercase letters, numbers or hyphens")
                    }
                    guard !used.contains(manifest.id) else { throw PluginError.invalid("Duplicate module ID: \(manifest.id)") }
                    guard !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          manifest.name.count <= 80 else { throw PluginError.invalid("Invalid module name") }
                    guard !manifest.executable.hasPrefix("/"), !manifest.executable.isEmpty else {
                        throw PluginError.invalid("Executable must be relative to the module directory")
                    }
                    let base = dir.resolvingSymlinksInPath().standardizedFileURL
                    let executable = dir.appendingPathComponent(manifest.executable).resolvingSymlinksInPath().standardizedFileURL
                    guard executable.path.hasPrefix(base.path + "/"),
                          fm.isExecutableFile(atPath: executable.path),
                          (try? executable.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                        throw PluginError.invalid("Executable must be a regular executable file inside its own module")
                    }
                    let start = manifest.startTimeoutSeconds ?? 20
                    let stop = manifest.stopTimeoutSeconds ?? 60
                    let status = manifest.statusTimeoutSeconds ?? 4
                    guard (1...120).contains(start), (10...300).contains(stop), (1...10).contains(status) else {
                        throw PluginError.invalid("Invalid action timeout")
                    }
                    let fields = manifest.settings ?? []
                    guard Set(fields.map(\.key)).count == fields.count,
                          fields.allSatisfy({ $0.key.range(of: "^[A-Za-z][A-Za-z0-9]*$", options: .regularExpression) != nil && ["string", "integer"].contains($0.type) }) else {
                        throw PluginError.invalid("Invalid settings schema")
                    }
                    let infoTimeout = manifest.infoTimeoutSeconds ?? 5
                    guard (1...15).contains(infoTimeout) else {
                        throw PluginError.invalid("Invalid info timeout (1–15 seconds)")
                    }
                    if manifest.supportsInfo != true,
                       manifest.ui?.sections.contains(where: { section in section.items.contains(where: { $0.type == "info" }) }) == true {
                        throw PluginError.invalid("An info item requires supportsInfo: true")
                    }
                    if let ui = manifest.ui {
                        guard ui.sections.count <= 20,
                              Set(ui.sections.map(\.id)).count == ui.sections.count else {
                            throw PluginError.invalid("Duplicate or excessive UI sections")
                        }
                        let keys = Set(fields.map(\.key))
                        for section in ui.sections {
                            guard section.id.range(of: "^[A-Za-z][A-Za-z0-9-]{0,39}$", options: .regularExpression) != nil,
                                  section.items.count <= 50,
                                  !section.title.isEmpty,
                                  section.title.values.allSatisfy({ !$0.isEmpty && $0.count <= 200 }) else {
                                throw PluginError.invalid("Invalid UI section")
                            }
                            for item in section.items {
                                let valid: Bool
                                switch item.type {
                                case "text": valid = item.key == nil && item.label == nil && item.text?.values.contains(where: { !$0.isEmpty && $0.count <= 2000 }) == true
                                case "info": valid = item.text == nil && item.key?.range(of: "^[A-Za-z][A-Za-z0-9]*$", options: .regularExpression) != nil && item.label?.isEmpty == false
                                case "setting": valid = item.text == nil && item.label == nil && item.key.map { keys.contains($0) } == true
                                default: valid = false
                                }
                                guard valid else { throw PluginError.invalid("Invalid UI item in section \(section.id)") }
                            }
                        }
                    }
                    used.insert(manifest.id)
                    found.append(PluginDescriptor(id: manifest.id, name: manifest.name,
                        executable: executable, directory: base,
                        symbol: ModuleSymbol.resolved(manifest.symbol ?? ModuleSymbol.fallback),
                        stopOrder: manifest.stopOrder ?? 50,
                        startTimeout: start, stopTimeout: stop, statusTimeout: status,
                        settings: fields, supportsValidate: manifest.supportsValidate ?? false,
                        supportsInfo: manifest.supportsInfo ?? false, infoTimeout: infoTimeout, ui: manifest.ui))
                } catch {
                    issues.append(PluginIssue(id: folder, reason: error.localizedDescription))
                }
            }
        }
        return (found, issues)
    }
    static func active() -> [PluginDescriptor] {
        let enabled = enabledIDs()
        return discover().modules.filter { enabled.contains($0.id) }
    }
}
