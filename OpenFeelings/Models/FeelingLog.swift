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

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        selection: EmotionSelection,
        intensity: Int?,
        note: String,
        healthSyncStatus: HealthSyncStatus = .notRequested
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
}
