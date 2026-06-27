// OpenFeelings/Services/FeelingLogService.swift
import SwiftData
import Foundation

/// One shared new-entry persistence path for every surface (wizard, quick
/// entry, Siri). Pure persistence: builds + inserts + first-saves the log and
/// returns it with `.pending`/`.notRequested`. Navigation and the (slow,
/// possibly permission-bound) HealthKit write are the caller's to schedule —
/// `syncHealth` is provided for that second phase.
enum FeelingLogService {
    @MainActor
    @discardableResult
    static func persist(
        draft: CheckInDraft,
        captureSource: String,
        into context: ModelContext,
        healthEnabled: Bool
    ) -> FeelingLog? {
        guard let selection = draft.selection, selection.isComplete else { return nil }
        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = FeelingLog(
            selection: selection,
            intensity: draft.includeIntensity ? Int(draft.intensity.rounded()) : nil,
            note: trimmedNote,
            healthSyncStatus: healthEnabled ? .pending : .notRequested,
            bodyRegions: BodyRegion.allCases.filter { draft.bodyRegions.contains($0) },
            bodySensations: BodySensation.allCases.filter { draft.bodySensations.contains($0) },
            contextPlaces: ContextPlace.allCases.filter { draft.contextPlaces.contains($0) },
            contextPeople: ContextPeople.allCases.filter { draft.contextPeople.contains($0) },
            triggers: Trigger.allCases.filter { draft.triggers.contains($0) },
            coping: Coping.allCases.filter { draft.coping.contains($0) },
            moodEnergy: draft.includeMoodScale ? draft.moodEnergy : nil,
            moodValence: draft.includeMoodScale ? draft.moodValence : nil,
            captureSource: captureSource
        )
        // The main init builds from an EmotionSelection and has no slot for raw
        // custom-region IDs, so set them after construction (mirrors CheckInView).
        log.customBodyRegionIDs = Array(draft.customBodyRegionIDs)
        context.insert(log)
        try? context.save()
        return log
    }

    @MainActor
    static func syncHealth(
        _ log: FeelingLog,
        healthService: HealthService,
        healthEnabled: Bool,
        into context: ModelContext
    ) async {
        log.healthSyncStatus = await healthService.save(log: log, isEnabled: healthEnabled)
        try? context.save()
    }
}
