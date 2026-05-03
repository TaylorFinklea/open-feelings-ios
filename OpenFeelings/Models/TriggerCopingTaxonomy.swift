import Foundation

/// What brought the feeling on. Therapy-relevant categories.
/// Stored on FeelingLog as a comma-separated raw String for SwiftData
/// compatibility (mirrors the BodyRegion / ContextPlace pattern).
enum Trigger: String, CaseIterable, Hashable, Sendable, Identifiable {
    case conflict, news, memory, anticipation, sleep, hunger, boundaries, transition, body, unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conflict:     "Conflict"
        case .news:         "News"
        case .memory:       "Memory"
        case .anticipation: "Anticipation"
        case .sleep:        "Sleep"
        case .hunger:       "Hunger"
        case .boundaries:   "Boundaries"
        case .transition:   "Transition"
        case .body:         "Body"
        case .unknown:      "Unknown"
        }
    }

    static func parseList(_ raw: String) -> [Trigger] {
        raw.split(separator: ",").compactMap { Trigger(rawValue: String($0)) }
    }

    static func encodeList(_ list: [Trigger]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}

/// What helped the user move through the feeling.
enum Coping: String, CaseIterable, Hashable, Sendable, Identifiable {
    case breath, walk, talk, journal, music, rest, food, movement, nature, stillness

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breath:    "Breath"
        case .walk:      "Walk"
        case .talk:      "Talk"
        case .journal:   "Journal"
        case .music:     "Music"
        case .rest:      "Rest"
        case .food:      "Food"
        case .movement:  "Movement"
        case .nature:    "Nature"
        case .stillness: "Stillness"
        }
    }

    static func parseList(_ raw: String) -> [Coping] {
        raw.split(separator: ",").compactMap { Coping(rawValue: String($0)) }
    }

    static func encodeList(_ list: [Coping]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}
