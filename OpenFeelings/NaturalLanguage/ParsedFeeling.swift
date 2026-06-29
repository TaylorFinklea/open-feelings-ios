import Foundation

/// The result of parsing one natural-language utterance into a (possibly
/// partial) feeling. Pure value type — no SwiftData / SwiftUI / Siri / FM.
/// `core == nil` means nothing in the taxonomy matched; `rawUtterance` is
/// always preserved so the user's words are never lost. Shared iOS + watchOS.
struct ParsedFeeling: Equatable {
    enum Confidence { case high, low, none }

    var core: EmotionCore?
    var secondary: EmotionSecondary?
    var specific: EmotionSpecific?
    var intensity: Int?
    var note: String
    var confidence: Confidence
    var rawUtterance: String
}
