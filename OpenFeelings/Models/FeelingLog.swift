import Foundation
import SwiftData

enum HealthSyncStatus: String, CaseIterable, Codable {
    case notRequested
    case pending
    case synced
    case permissionDenied
    case failed

    var label: String {
        switch self {
        case .notRequested:
            "Not sent to Apple Health"
        case .pending:
            "Apple Health pending"
        case .synced:
            "Saved to Apple Health"
        case .permissionDenied:
            "Apple Health permission needed"
        case .failed:
            "Apple Health save failed"
        }
    }
}

@Model
final class FeelingLog {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var coreID: String = ""
    var coreName: String = ""
    var secondaryID: String = ""
    var secondaryName: String = ""
    var specificID: String = ""
    var specificName: String = ""
    var intensity: Int?
    var note: String = ""
    var healthSyncStatusRaw: String = HealthSyncStatus.notRequested.rawValue
    var bodyRegionsRaw: String = ""
    var bodySensationsRaw: String = ""
    var contextPlacesRaw: String = ""
    var contextPeopleRaw: String = ""
    var triggersRaw: String = ""
    var copingRaw: String = ""
    var moodEnergy: Double?
    var moodValence: Double?
    var captureSource: String = "phone"

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        selection: EmotionSelection,
        intensity: Int?,
        note: String,
        healthSyncStatus: HealthSyncStatus = .notRequested,
        bodyRegions: [BodyRegion] = [],
        bodySensations: [BodySensation] = [],
        contextPlaces: [ContextPlace] = [],
        contextPeople: [ContextPeople] = [],
        triggers: [Trigger] = [],
        coping: [Coping] = [],
        moodEnergy: Double? = nil,
        moodValence: Double? = nil,
        captureSource: String = "phone"
    ) {
        self.id = id
        self.createdAt = createdAt
        coreID = selection.core.id
        coreName = selection.core.name
        secondaryID = selection.secondary?.id ?? ""
        secondaryName = selection.secondary?.name ?? ""
        specificID = selection.specific?.id ?? ""
        specificName = selection.specific?.name ?? ""
        self.intensity = intensity
        self.note = note
        healthSyncStatusRaw = healthSyncStatus.rawValue
        bodyRegionsRaw = BodyRegion.encodeList(bodyRegions)
        bodySensationsRaw = BodySensation.encodeList(bodySensations)
        contextPlacesRaw = ContextPlace.encodeList(contextPlaces)
        contextPeopleRaw = ContextPeople.encodeList(contextPeople)
        triggersRaw = Trigger.encodeList(triggers)
        copingRaw = Coping.encodeList(coping)
        self.moodEnergy = moodEnergy
        self.moodValence = moodValence
        self.captureSource = captureSource
    }

    // Convenience init for entries captured from a non-iPhone source (e.g., Apple Watch),
    // where only the core feeling is known. Secondary/specific path stay empty so the
    // Today view shows "<Core>" cleanly and a later iOS edit can fill in detail.
    init(
        id: UUID,
        createdAt: Date,
        coreID: String,
        coreName: String,
        intensity: Int?,
        note: String,
        healthSyncStatus: HealthSyncStatus,
        captureSource: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.coreID = coreID
        self.coreName = coreName
        self.intensity = intensity
        self.note = note
        healthSyncStatusRaw = healthSyncStatus.rawValue
        self.captureSource = captureSource
    }

    var healthSyncStatus: HealthSyncStatus {
        get { HealthSyncStatus(rawValue: healthSyncStatusRaw) ?? .notRequested }
        set { healthSyncStatusRaw = newValue.rawValue }
    }

    var emotionTitle: String {
        specificName.isEmpty ? secondaryName : specificName
    }

    var pathTitle: String {
        [coreName, secondaryName, specificName]
            .filter { !$0.isEmpty }
            .joined(separator: " > ")
    }

    var bodyRegions: [BodyRegion] {
        get { BodyRegion.parseList(bodyRegionsRaw) }
        set { bodyRegionsRaw = BodyRegion.encodeList(newValue) }
    }

    var bodySensations: [BodySensation] {
        get { BodySensation.parseList(bodySensationsRaw) }
        set { bodySensationsRaw = BodySensation.encodeList(newValue) }
    }

    var contextPlaces: [ContextPlace] {
        get { ContextPlace.parseList(contextPlacesRaw) }
        set { contextPlacesRaw = ContextPlace.encodeList(newValue) }
    }

    var contextPeople: [ContextPeople] {
        get { ContextPeople.parseList(contextPeopleRaw) }
        set { contextPeopleRaw = ContextPeople.encodeList(newValue) }
    }

    var triggers: [Trigger] {
        get { Trigger.parseList(triggersRaw) }
        set { triggersRaw = Trigger.encodeList(newValue) }
    }

    var coping: [Coping] {
        get { Coping.parseList(copingRaw) }
        set { copingRaw = Coping.encodeList(newValue) }
    }
}
