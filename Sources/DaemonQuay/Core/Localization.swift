import Foundation
import Combine

/// Application UI language; independent of managed services and their JSON.
@MainActor
final class Localization: ObservableObject {
    static let shared = Localization()
    @Published var preference: String {
        didSet {
            if preference != oldValue { _ = AppPreferences.saveLanguage(preference) }
        }
    }
    private var catalogs: [String: [String: String]] = [:]
    private init() {
        preference = AppPreferences.language()
        for language in ["en", "zh-Hant"] {
            if let url = Bundle.main.url(forResource: language, withExtension: "json", subdirectory: "Languages"),
               let data = try? Data(contentsOf: url),
               let strings = try? JSONDecoder().decode([String: String].self, from: data) {
                catalogs[language] = strings
            }
        }
    }
    var activeLanguage: String {
        return preference == "zh-Hant" ? "zh-Hant" : "en"
    }
    func text(_ key: String) -> String {
        catalogs[activeLanguage]?[key] ?? catalogs["en"]?[key] ?? key
    }
    func format(_ key: String, _ value: CVarArg) -> String {
        String(format: text(key), locale: Locale(identifier: activeLanguage), arguments: [value])
    }
}
