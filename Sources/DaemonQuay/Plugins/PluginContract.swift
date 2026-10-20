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

// Optional, declarative presentation. Only known types are accepted by the registry.
// Modules never provide executable UI code.
struct PluginUIItem: Codable, Hashable {
    let type: String // text | info | setting
    let key: String?
    let label: [String: String]?
    let text: [String: String]?
}

struct PluginUISection: Codable, Hashable, Identifiable {
    let id: String
    let title: [String: String]
    let items: [PluginUIItem]
}

struct PluginUI: Codable, Hashable {
    let sections: [PluginUISection]
}

struct PluginInfoResponse: Decodable {
    let values: [String: String]
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
    let supportsInfo: Bool?
    let infoTimeoutSeconds: Int?
    let ui: PluginUI?
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
    let supportsInfo: Bool
    let infoTimeout: Int
    let ui: PluginUI?
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
