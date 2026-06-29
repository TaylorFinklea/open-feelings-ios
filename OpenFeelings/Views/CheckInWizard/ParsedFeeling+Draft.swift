import Foundation

extension ParsedFeeling {
    /// Map into the existing wizard draft (iOS) so both surfaces reuse the same
    /// persistence + review UI. Leaves `selection` nil when no core resolved.
    /// iOS-only: CheckInDraft lives in the iOS Views layer.
    func toDraft() -> CheckInDraft {
        var draft = CheckInDraft()
        if let core {
            draft.selection = EmotionSelection(core: core, secondary: secondary, specific: specific)
        }
        draft.note = note
        draft.includeIntensity = intensity != nil
        draft.intensity = Double(intensity ?? 3)
        return draft
    }
}
