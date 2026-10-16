import Foundation

/// DaemonQuay-only preferences live beside onboarding metadata in settings.json.
/// Missing keys preserve backwards compatibility with existing installations.
enum AppPreferences {
    private static let metadataKey = "_daemonquay"
    private static let languageKey = "language"
    private static let startupHintKey = "showStartupHint"
    private static let legacyLanguageKey = "DaemonQuayUILanguage"

    private static func normalizedLanguage(_ candidate: String?) -> String? {
        guard let candidate = candidate, ["en", "zh-Hant"].contains(candidate) else { return nil }
        return candidate
    }

    /// The menu-bar pointer hint is enabled unless the user opts out.
    static func showStartupHint() -> Bool {
        guard let data = try? Data(contentsOf: Paths.config),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metadata = root[metadataKey] as? [String: Any],
              let saved = metadata[startupHintKey] as? Bool else { return true }
        return saved
    }

    @discardableResult
    static func saveStartupHint(_ enabled: Bool) -> Bool {
        guard let data = try? Data(contentsOf: Paths.config),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        var metadata = root[metadataKey] as? [String: Any] ?? [:]
        metadata[startupHintKey] = enabled
        root[metadataKey] = metadata
        guard let output = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else { return false }
        do {
            try output.write(to: Paths.config, options: .atomic)
            return true
        } catch {
            NSLog("DaemonQuay: could not save startup hint preference: %@", String(describing: error))
            return false
        }
    }

    static func language() -> String {
        if let data = try? Data(contentsOf: Paths.config),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let metadata = root[metadataKey] as? [String: Any],
           let stored = normalizedLanguage(metadata[languageKey] as? String) {
            return stored
        }
        // Read the historical preference once during migration. Never remove it automatically.
        let migrated = normalizedLanguage(UserDefaults.standard.string(forKey: legacyLanguageKey)) ?? "en"
        _ = saveLanguage(migrated)
        return migrated
    }

    /// Preserve the complete settings document and all module-specific keys.
    @discardableResult
    static func saveLanguage(_ language: String) -> Bool {
        guard let normalized = normalizedLanguage(language),
              let data = try? Data(contentsOf: Paths.config),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        var metadata = root[metadataKey] as? [String: Any] ?? [:]
        metadata[languageKey] = normalized
        root[metadataKey] = metadata
        guard let output = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else { return false }
        do {
            try output.write(to: Paths.config, options: .atomic)
            return true
        } catch {
            NSLog("DaemonQuay: could not save language preference: %@", String(describing: error))
            return false
        }
    }
}
