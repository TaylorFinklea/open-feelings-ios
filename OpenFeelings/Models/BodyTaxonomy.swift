import Foundation

/// Regions a user can tap when logging a check-in's somatic location.
/// Stored on FeelingLog as a comma-separated raw String for SwiftData
/// compatibility (mirrors the healthSyncStatusRaw pattern).
enum BodyRegion: String, CaseIterable, Hashable, Sendable, Identifiable {
    case head, throat, chest, stomach, gut, shoulders, back, hands, legs, wholeBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .head:      "Head"
        case .throat:    "Throat"
        case .chest:     "Chest"
        case .stomach:   "Stomach"
        case .gut:       "Gut"
        case .shoulders: "Shoulders"
        case .back:      "Back"
        case .hands:     "Hands"
        case .legs:      "Legs"
        case .wholeBody: "Whole body"
        }
    }

    /// Parses a comma-separated raw string into typed regions, dropping any
    /// unknown tokens silently.
    static func parseList(_ raw: String) -> [BodyRegion] {
        raw.split(separator: ",").compactMap { BodyRegion(rawValue: String($0)) }
    }

    /// Encodes a typed list back into a comma-separated raw string.
    static func encodeList(_ list: [BodyRegion]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}

/// Sensation descriptors a user can attach when at least one body region is
/// selected ("how does it feel?").
enum BodySensation: String, CaseIterable, Hashable, Sendable, Identifiable {
    case tight, warm, cool, buzzing, fluttery, heavy, numb, sharp, pleasant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tight:    "Tight"
        case .warm:     "Warm"
        case .cool:     "Cool"
        case .buzzing:  "Buzzing"
        case .fluttery: "Fluttery"
        case .heavy:    "Heavy"
        case .numb:     "Numb"
        case .sharp:    "Sharp"
        case .pleasant: "Pleasant"
        }
    }

    static func parseList(_ raw: String) -> [BodySensation] {
        raw.split(separator: ",").compactMap { BodySensation(rawValue: String($0)) }
    }

    static func encodeList(_ list: [BodySensation]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}
