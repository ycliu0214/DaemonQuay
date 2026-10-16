import Foundation

/// Presentation only. Hidden modules stay installed/enabled and remain subject to
/// status polling and safe shutdown checks.
enum ServiceVisibility {
    static let file = Paths.base.appendingPathComponent("hidden-services.json")
    static func read() -> Set<String> {
        guard let data = try? Data(contentsOf: file),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(values)
    }
    static func save(_ ids: Set<String>) throws {
        try FileManager.default.createDirectory(at: Paths.base, withIntermediateDirectories: true)
        try JSONEncoder().encode(ids.sorted()).write(to: file, options: .atomic)
    }
}
