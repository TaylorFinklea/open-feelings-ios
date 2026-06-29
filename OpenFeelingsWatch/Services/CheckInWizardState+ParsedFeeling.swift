// OpenFeelingsWatch/Services/CheckInWizardState+ParsedFeeling.swift
import Foundation

extension CheckInWizardState {
    /// Seed the watch wizard from a parsed utterance. Body fields are left
    /// untouched (NL doesn't parse them). Intensity defaults to the watch
    /// neutral 3 when the utterance stated none — the watch always records an
    /// intensity (see the routing: a high-confidence parse with no intensity is
    /// routed through the IntensityPicker so the user sets it intentionally).
    /// Callers MUST `reset()` before `apply` (the wizard is a shared instance).
    func apply(_ parsed: ParsedFeeling) {
        core = parsed.core
        secondary = parsed.secondary
        specific = parsed.specific
        intensity = parsed.intensity ?? 3
        note = parsed.note
    }
}
