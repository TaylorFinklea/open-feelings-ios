import Foundation

/// Where the user was when they logged a check-in.
/// Stored on FeelingLog as a comma-separated raw String for SwiftData
/// compatibility (mirrors the BodyRegion / healthSyncStatusRaw pattern).
enum ContextPlace: String, CaseIterable, Hashable, Sendable, Identifiable {
    case home, work, school, outside, commute, publicSpace, traveling, virtual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:        "Home"
        case .work:        "Work"
        case .school:      "School"
        case .outside:     "Outside"
        case .commute:     "Commute"
        case .publicSpace: "Public"
        case .traveling:   "Traveling"
        case .virtual:     "Virtual"
        }
    }

    static func parseList(_ raw: String) -> [ContextPlace] {
        raw.split(separator: ",").compactMap { ContextPlace(rawValue: String($0)) }
    }

    static func encodeList(_ list: [ContextPlace]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}

/// Who the user was with.
enum ContextPeople: String, CaseIterable, Hashable, Sendable, Identifiable {
    case alone, partner, family, friends, coworkers, stranger, multiple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alone:     "Alone"
        case .partner:   "Partner"
        case .family:    "Family"
        case .friends:   "Friends"
        case .coworkers: "Coworkers"
        case .stranger:  "Stranger"
        case .multiple:  "Multiple"
        }
    }

    static func parseList(_ raw: String) -> [ContextPeople] {
        raw.split(separator: ",").compactMap { ContextPeople(rawValue: String($0)) }
    }

    static func encodeList(_ list: [ContextPeople]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}
