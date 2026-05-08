import Foundation

/// One step in the Check In wizard. Order is fixed — see `CheckInFlowEngine`
/// for which kinds are included for a given user setting.
///
/// `body`, `feeling`, `reflect` are structural (always-or-required). The
/// rest are optional dimensions that can be promoted from "More detail"
/// to first-class steps via Settings → Check In flow.
enum CheckInStepKind: String, CaseIterable, Identifiable, Sendable {
    case body
    case feeling
    case strength
    case sensations
    case context
    case triggers
    case coping
    case mood
    case reflect

    var id: String { rawValue }

    /// Stable key used in the `checkInPromotedSteps` AppStorage CSV.
    var storageKey: String { rawValue }

    /// Whether the user can promote this kind to a first-class step.
    /// `body` is gated on `checkInBodyFirst`; the rest of the structural
    /// kinds are not user-configurable.
    var isPromotable: Bool {
        switch self {
        case .sensations, .context, .triggers, .coping, .mood, .strength:
            true
        case .body, .feeling, .reflect:
            false
        }
    }

    /// Parse a CSV of step keys into a typed list, dropping unknown tokens.
    static func parseList(_ raw: String) -> [CheckInStepKind] {
        raw.split(separator: ",").compactMap { CheckInStepKind(rawValue: String($0)) }
    }

    /// Encode a typed list back to CSV.
    static func encodeList(_ kinds: [CheckInStepKind]) -> String {
        kinds.map(\.storageKey).joined(separator: ",")
    }
}
