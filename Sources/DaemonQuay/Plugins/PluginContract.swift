import Foundation

// One contract for bundled and user-installed modules. No hard-coded service IDs.
struct PluginSettingField: Codable, Hashable, Identifiable {
    let key: String
    let type: String // string | integer
    let labels: [String: String]
    var id: String { key }
    func label(_ locale: String) -> String {
        labels[locale] ?? labels["en"] ?? key
    }
}

struct PluginManifest: Codable {
    let apiVersion: Int
    let id: String
    let name: String
    let executable: String
    let symbol: String?
    let stopOrder: Int?
    let startTimeoutSeconds: Int?
    let stopTimeoutSeconds: Int?
    let statusTimeoutSeconds: Int?
    let settings: [PluginSettingField]?
    let supportsValidate: Bool?
}

struct PluginDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    let executable: URL
    let directory: URL
    let symbol: String
    let stopOrder: Int
    let startTimeout: Int
    let stopTimeout: Int
    let statusTimeout: Int
    let settings: [PluginSettingField]
    let supportsValidate: Bool
}

/// One JSON response on stdout. A module may be a compiled program or an executable script.
struct PluginResponse: Decodable {
    let state: String
    let message: String?
}

struct PluginIssue: Identifiable {
    let id: String
    let reason: String
}

enum PluginError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case .invalid(let reason) = self { return reason }
        return "Invalid module"
    }
}
