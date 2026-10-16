import Foundation

enum ServiceStatus: Equatable {
    case running, stopped, external, error
    var localizationKey: String {
        switch self {
        case .running: return "common.running"
        case .stopped: return "common.stopped"
        case .external: return "common.external"
        case .error: return "common.error"
        }
    }
    var isActive: Bool { self != .stopped }
}

enum LogChannel: String, CaseIterable { case log, error }

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let base = home.appendingPathComponent(".local/share/DaemonQuay", isDirectory: true)
    static let config = base.appendingPathComponent("settings.json")
    static func log(_ id: String, error: Bool = false) -> URL {
        base.appendingPathComponent("logs/\(id)/\(error ? "error" : "log").log")
    }
    static func legacyLog(_ id: String, error: Bool = false) -> URL {
        base.appendingPathComponent("logs/\(id).\(error ? "err" : "out").log")
    }
}

struct CommandResult {
    let code: Int32
    let output: String
}
