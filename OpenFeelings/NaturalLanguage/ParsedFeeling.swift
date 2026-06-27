import Foundation

/// The result of parsing one natural-language utterance into a (possibly
/// partial) feeling. Pure value type — no SwiftData / SwiftUI / Siri / FM.
/// `core == nil` means nothing in the taxonomy matched; `rawUtterance` is
/// always preserved so the user's words are never lost.
struct ParsedFeeling: Equatable {
    enum Confidence { case high, low, none }

    var core: EmotionCore?
    var secondary: EmotionSecondary?
    var specific: EmotionSpecific?
    var intensity: Int?
    var note: String
    var confidence: Confidence
    var rawUtterance: String

    /// Map into the existing wizard draft so both surfaces reuse the same
    /// persistence + review UI. Leaves `selection` nil when no core resolved.
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
