import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case checkIn
    case insights
    case direction
    case settings

    var title: String {
        switch self {
        case .today:      "Today"
        case .checkIn:    "Check In"
        case .insights:   "Insights"
        case .direction:  "Direction"
        case .settings:   "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:      "sun.horizon"
        case .checkIn:    "circle.grid.3x3"
        case .insights:   "chart.line.uptrend.xyaxis"
        case .direction:  "leaf"
        case .settings:   "gearshape"
        }
    }
}

/// Sub-route under the Today tab. Today is the parent route; pushing
/// `.full` onto its path navigates to the full History list.
enum HistoryRoute: Hashable, Sendable {
    case full
}

/// Cross-tab filter state. When non-nil, History narrows its list to logs
/// matching the filter. Set by Insights chart taps; cleared by the History
/// banner's Clear affordance.
enum HistoryFilter: Equatable, Hashable, Sendable {
    /// Match logs whose secondary name (e.g. "Anxious", "Hopeful") equals
    /// this string. Case- and accent-sensitive — these come from the
    /// taxonomy directly, not user input.
    case secondaryName(String)
    case coreID(String)
    case bodyRegion(BodyRegion)
    case weekday(Int)

    var displayLabel: String {
        switch self {
        case .secondaryName(let name): name
        case .coreID(let id):
            EmotionTaxonomy.cores.first { $0.id == id }?.name ?? id
        case .bodyRegion(let region):
            region.displayName
        case .weekday(let weekday):
            Self.weekdayLabel(for: weekday)
        }
    }

    private static func weekdayLabel(for weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
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

    /// Optional cross-tab filter. Insights sets this and switches to History;
    /// History reads it and narrows its query.
    var historyFilter: HistoryFilter?

    /// Path for the Today tab's NavigationStack. Mutating this from outside
    /// TodayView lets other tabs (e.g. Insights) deep-link into History.
    var todayPath: [HistoryRoute] = []

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    /// Switch to History under the Today tab with a filter pre-applied.
    /// Programmatically appends `.full` to the Today nav path so the user
    /// lands on the filtered list, not on Today.
    func drillIntoHistory(filter: HistoryFilter) {
        historyFilter = filter
        selectedTab = .today
        if !todayPath.contains(.full) {
            todayPath.append(.full)
        }
    }

    /// Clear the active history filter — dismisses the filter banner and
    /// restores the unfiltered History list.
    func clearHistoryFilter() {
        historyFilter = nil
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
