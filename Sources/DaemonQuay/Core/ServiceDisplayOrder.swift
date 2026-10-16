import Foundation

/// User preference only. Never changes module metadata or shutdown sequencing.
enum ServiceDisplayOrder {
    static let file = Paths.base.appendingPathComponent("service-order.json")

    static func read() -> [String] {
        guard let data = try? Data(contentsOf: file),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    static func ordered(_ modules: [PluginDescriptor]) -> [PluginDescriptor] {
        let preference = read()
        let positions = Dictionary(uniqueKeysWithValues: preference.enumerated().map { ($0.element, $0.offset) })
        return modules.sorted { lhs, rhs in
            let l = positions[lhs.id] ?? Int.max
            let r = positions[rhs.id] ?? Int.max
            return l == r ? lhs.id < rhs.id : l < r
        }
    }

    static func save(_ identifiers: [String]) throws {
        try FileManager.default.createDirectory(at: Paths.base, withIntermediateDirectories: true)
        try JSONEncoder().encode(identifiers).write(to: file, options: .atomic)
    }
}
