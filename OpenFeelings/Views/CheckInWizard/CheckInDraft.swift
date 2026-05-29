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
    var customBodyRegionIDs: Set<UUID> = []
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
            if bodyRegions == [region] && customBodyRegionIDs.isEmpty {
                bodyRegions = []
            } else {
                bodyRegions = [region]
                customBodyRegionIDs = []
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

    /// Toggles a user-defined region. Custom regions never act exclusively —
    /// they coexist with built-ins. But picking one clears Everywhere/Nowhere,
    /// since those are still meant to mean "no specific location."
    mutating func toggleCustomRegion(_ id: UUID) {
        if bodyRegions.contains(.wholeBody) || bodyRegions.contains(.nowhere) {
            bodyRegions.remove(.wholeBody)
            bodyRegions.remove(.nowhere)
        }

        if customBodyRegionIDs.contains(id) {
            customBodyRegionIDs.remove(id)
        } else {
            customBodyRegionIDs.insert(id)
        }
    }

    mutating func reset() {
        self = CheckInDraft()
    }

    // MARK: - Edit round-trip (full-edit of a saved FeelingLog)

    /// Reconstruct a draft from a saved log so the wizard's steps can edit
    /// every field. Mirrors the `CheckInView.save()` field mapping in
    /// reverse. The emotion path uses `EmotionTaxonomy.selection`, which
    /// returns nil secondary/specific for stop-at-any-level entries.
    static func from(log: FeelingLog) -> CheckInDraft {
        var draft = CheckInDraft()
        draft.selection = EmotionTaxonomy.selection(
            coreID: log.coreID,
            secondaryID: log.secondaryID.isEmpty ? nil : log.secondaryID,
            specificID: log.specificID.isEmpty ? nil : log.specificID
        )
        draft.note = log.note
        draft.includeIntensity = log.intensity != nil
        draft.intensity = Double(log.intensity ?? 3)
        draft.includeMoodScale = log.moodEnergy != nil || log.moodValence != nil
        draft.moodEnergy = log.moodEnergy ?? 0
        draft.moodValence = log.moodValence ?? 0
        draft.bodyRegions = Set(log.bodyRegions)
        draft.customBodyRegionIDs = Set(log.customBodyRegionIDs)
        draft.bodySensations = Set(log.bodySensations)
        draft.contextPlaces = Set(log.contextPlaces)
        draft.contextPeople = Set(log.contextPeople)
        draft.triggers = Set(log.triggers)
        draft.coping = Set(log.coping)
        return draft
    }

    /// Write the draft's editable fields back onto an existing log. Preserves
    /// `id`, `createdAt`, `healthSyncStatus`, and `captureSource` — editing
    /// changes what was recorded, not when or where. No-op if there is no
    /// selection (the wizard gates Save on `canSave`).
    func apply(to log: FeelingLog) {
        guard let selection else { return }
        log.coreID = selection.core.id
        log.coreName = selection.core.name
        log.secondaryID = selection.secondary?.id ?? ""
        log.secondaryName = selection.secondary?.name ?? ""
        log.specificID = selection.specific?.id ?? ""
        log.specificName = selection.specific?.name ?? ""
        log.intensity = includeIntensity ? Int(intensity.rounded()) : nil
        log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        log.bodyRegions = BodyRegion.allCases.filter { bodyRegions.contains($0) }
        log.customBodyRegionIDs = Array(customBodyRegionIDs)
        log.bodySensations = BodySensation.allCases.filter { bodySensations.contains($0) }
        log.contextPlaces = ContextPlace.allCases.filter { contextPlaces.contains($0) }
        log.contextPeople = ContextPeople.allCases.filter { contextPeople.contains($0) }
        log.triggers = Trigger.allCases.filter { triggers.contains($0) }
        log.coping = Coping.allCases.filter { coping.contains($0) }
        log.moodEnergy = includeMoodScale ? moodEnergy : nil
        log.moodValence = includeMoodScale ? moodValence : nil
    }
}
