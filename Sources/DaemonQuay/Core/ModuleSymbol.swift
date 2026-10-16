import AppKit
import SwiftUI

/// All module-owned SF Symbol names use the same safe fallback.
enum ModuleSymbol {
    static let fallback = "shippingbox"

    static func resolved(_ requested: String) -> String {
        let name = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil else {
            return fallback
        }
        return name
    }

    static func image(_ requested: String) -> Image {
        Image(systemName: resolved(requested))
    }
}
