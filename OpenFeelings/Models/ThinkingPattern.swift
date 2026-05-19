import Foundation

/// The 8 curated "thinking patterns" surfaced as chips in the thought-record
/// wizard. Soft-renamed from Burns's 10 cognitive distortions to fit
/// Open Feelings' non-clinical tone (see spec for the Burns→our-name map).
/// Stored on `ThoughtRecord.patternsRaw` as a comma-joined list of raw
/// values; the computed `patterns` accessor decodes via `parseList`.
enum ThinkingPattern: String, CaseIterable, Codable, Sendable, Identifiable {
    case blackAndWhite
    case mindReading
    case worstCase
    case allMyFault
    case shouldStorm
    case filterTheGood
    case fortuneTelling
    case alwaysNever

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blackAndWhite:  "Black-and-white"
        case .mindReading:    "Mind-reading"
        case .worstCase:      "Worst-case"
        case .allMyFault:     "All my fault"
        case .shouldStorm:    "Should-storm"
        case .filterTheGood:  "Filter the good out"
        case .fortuneTelling: "Fortune-telling"
        case .alwaysNever:    "Always / never"
        }
    }

    var description: String {
        switch self {
        case .blackAndWhite:  "Seeing things in just two extremes, no middle."
        case .mindReading:    "Assuming someone's thoughts without checking."
        case .worstCase:      "Skipping to the worst outcome you can picture."
        case .allMyFault:     "Taking responsibility for something outside your control."
        case .shouldStorm:    "Pile-up of \"I should…\" / \"I must…\" rules."
        case .filterTheGood:  "Noticing only what went wrong, missing what went right."
        case .fortuneTelling: "Predicting a bad future as if it's already true."
        case .alwaysNever:    "Stretching one event into a permanent pattern."
        }
    }

    static func parseList(_ raw: String) -> [ThinkingPattern] {
        guard !raw.isEmpty else { return [] }
        return raw.split(separator: ",")
                  .compactMap { ThinkingPattern(rawValue: String($0)) }
    }

    static func encodeList(_ list: [ThinkingPattern]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}
