import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case checkIn
    case insights
    case intentions
    case settings

    var title: String {
        switch self {
        case .today:      "Today"
        case .checkIn:    "Check In"
        case .insights:   "Insights"
        case .intentions: "Intentions"
        case .settings:   "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:      "sun.horizon"
        case .checkIn:    "circle.grid.3x3"
        case .insights:   "chart.line.uptrend.xyaxis"
        case .intentions: "leaf"
        case .settings:   "gearshape"
        }
    }
}

@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .today

    struct SavedRibbon: Equatable {
        let timestamp: Date
    }

    var savedRibbon: SavedRibbon?

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    /// Show the "Saved" ribbon for ~2 seconds.
    func ribbonAfterSave(now: Date = Date()) {
        savedRibbon = SavedRibbon(timestamp: now)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            savedRibbon = nil
        }
    }
}
