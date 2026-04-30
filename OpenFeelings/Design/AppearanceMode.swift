import SwiftUI

/// In-app override for the app's color scheme. Persisted via
/// @AppStorage("appearanceMode"); default is `.system` (follows the device).
enum AppearanceMode: String, CaseIterable, Hashable, Sendable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    /// Returns the SwiftUI ColorScheme to force, or nil to follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
