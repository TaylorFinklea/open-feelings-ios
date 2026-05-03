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
        contextPeople: [ContextPeople] = []
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
}
