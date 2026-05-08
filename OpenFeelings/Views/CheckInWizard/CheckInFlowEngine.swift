import Foundation

/// Pure value-type that decides the ordered list of `CheckInStepKind` for a
/// given user configuration. No I/O, no global state — fully testable.
enum CheckInFlowEngine {
    /// Returns the ordered list of steps the wizard renders.
    ///
    /// Layout rules:
    /// - `body` first (only when `bodyFirst` is true).
    /// - `sensations` is the only promoted kind that lands between `body` and
    ///   `feeling` — it has no meaning without regions to attach to.
    /// - `feeling` is always present.
    /// - The remaining promoted kinds (context, triggers, coping, strength, mood)
    ///   land between `feeling` and `reflect`, in that fixed order regardless of
    ///   the order they appear in `promotedSteps`.
    /// - `reflect` is always last.
    static func steps(bodyFirst: Bool, promotedSteps: Set<CheckInStepKind>) -> [CheckInStepKind] {
        var result: [CheckInStepKind] = []

        if bodyFirst {
            result.append(.body)
            if promotedSteps.contains(.sensations) {
                result.append(.sensations)
            }
        }

        result.append(.feeling)

        for kind in [CheckInStepKind.context, .triggers, .coping, .strength, .mood] {
            if promotedSteps.contains(kind) {
                result.append(kind)
            }
        }

        result.append(.reflect)
        return result
    }
}
