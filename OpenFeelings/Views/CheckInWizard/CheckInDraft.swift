import Foundation

/// All in-flight check-in state held by the wizard orchestrator. Pure value
/// type — testable without any SwiftUI environment.
struct CheckInDraft {
    var selection: EmotionSelection?
    var note: String = ""
    var includeIntensity: Bool = false
    var intensity: Double = 3
    var includeMoodScale: Bool = false
    var moodEnergy: Double = 0
    var moodValence: Double = 0
    var bodyRegions: Set<BodyRegion> = []
    var bodySensations: Set<BodySensation> = []
    var contextPlaces: Set<ContextPlace> = []
    var contextPeople: Set<ContextPeople> = []
    var triggers: Set<Trigger> = []
    var coping: Set<Coping> = []

    /// Whether the draft has enough state to save (just a complete emotion).
    var canSave: Bool {
        selection?.isComplete == true
    }

    /// Toggles a region with the Everywhere/Nowhere exclusivity rules:
    /// - Picking Everywhere or Nowhere replaces all selections with that one.
    /// - Picking any normal region while Everywhere/Nowhere is selected clears it.
    /// - Picking Everywhere when Nowhere is selected (or vice versa) replaces.
    mutating func toggleRegion(_ region: BodyRegion) {
        let isExclusive = (region == .wholeBody || region == .nowhere)
        let hasExclusive = bodyRegions.contains(.wholeBody) || bodyRegions.contains(.nowhere)

        if isExclusive {
            if bodyRegions == [region] {
                bodyRegions = []
            } else {
                bodyRegions = [region]
            }
            return
        }

        if hasExclusive {
            bodyRegions.remove(.wholeBody)
            bodyRegions.remove(.nowhere)
        }

        if bodyRegions.contains(region) {
            bodyRegions.remove(region)
        } else {
            bodyRegions.insert(region)
        }
    }

    mutating func reset() {
        self = CheckInDraft()
    }
}
