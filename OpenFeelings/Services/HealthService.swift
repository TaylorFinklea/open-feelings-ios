import Foundation
import HealthKit
import Observation

struct HealthStateOfMindMapping: Equatable {
    let valence: Double
    let labels: [HKStateOfMind.Label]
}

enum HealthKitMapper {
    static func mapping(coreID: String, secondaryID: String) -> HealthStateOfMindMapping {
        switch coreID {
        case "happy":
            HealthStateOfMindMapping(valence: 0.76, labels: happyLabels(secondaryID: secondaryID))
        case "sad":
            HealthStateOfMindMapping(valence: -0.68, labels: sadnessLabels(secondaryID: secondaryID))
        case "angry":
            HealthStateOfMindMapping(valence: -0.72, labels: angerLabels(secondaryID: secondaryID))
        case "fearful":
            HealthStateOfMindMapping(valence: -0.74, labels: fearLabels(secondaryID: secondaryID))
        case "disgusted":
            HealthStateOfMindMapping(valence: -0.62, labels: disgustLabels(secondaryID: secondaryID))
        default:
            HealthStateOfMindMapping(valence: 0, labels: [.indifferent])
        }
    }

    private static func happyLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "optimistic": [.hopeful, .joyful]
        case "peaceful": [.peaceful, .content]
        case "proud": [.proud, .confident]
        case "excited": [.excited, .joyful]
        case "powerful": [.confident, .proud]
        default: [.happy]
        }
    }

    private static func angerLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "humiliated": [.embarrassed, .angry]
        case "bitter": [.angry, .jealous]
        case "frustrated": [.frustrated, .annoyed]
        case "critical": [.irritated, .angry]
        case "distant": [.indifferent, .discouraged]
        default: [.angry]
        }
    }

    private static func fearLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "anxious": [.anxious, .worried]
        case "insecure": [.worried, .scared]
        case "weak": [.discouraged, .overwhelmed]
        case "rejected": [.sad, .scared]
        case "threatened": [.scared, .stressed]
        default: [.scared]
        }
    }

    private static func sadnessLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "lonely": [.lonely, .sad]
        case "vulnerable": [.sad, .worried]
        case "despair": [.sad, .discouraged]
        case "guilty": [.guilty, .ashamed]
        case "hurt": [.sad, .disappointed]
        default: [.sad]
        }
    }

    private static func disgustLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "repelled": [.disgusted]
        case "awful": [.disgusted, .overwhelmed]
        case "disenchanted": [.disappointed, .discouraged]
        case "disapproving": [.disgusted, .annoyed]
        case "startled": [.scared, .stressed]
        default: [.disgusted]
        }
    }
}

@MainActor
@Observable
final class HealthService {
    private let healthStore = HKHealthStore()

    var lastError: String?
    var authorizationStatus: HKAuthorizationStatus = .notDetermined

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func refreshAuthorizationStatus() {
        guard isAvailable else {
            authorizationStatus = .sharingDenied
            return
        }

        authorizationStatus = healthStore.authorizationStatus(for: HKObjectType.stateOfMindType())
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            lastError = "Apple Health is not available on this device."
            authorizationStatus = .sharingDenied
            return false
        }

        do {
            let type = HKObjectType.stateOfMindType()
            try await healthStore.requestAuthorization(toShare: [type], read: [])
            authorizationStatus = healthStore.authorizationStatus(for: type)
            return authorizationStatus == .sharingAuthorized
        } catch {
            lastError = error.localizedDescription
            refreshAuthorizationStatus()
            return false
        }
    }

    func save(log: FeelingLog, isEnabled: Bool) async -> HealthSyncStatus {
        guard isEnabled else {
            return .notRequested
        }

        guard isAvailable else {
            lastError = "Apple Health is not available on this device."
            return .failed
        }

        let type = HKObjectType.stateOfMindType()
        guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else {
            return .permissionDenied
        }

        let mapping = HealthKitMapper.mapping(coreID: log.coreID, secondaryID: log.secondaryID)
        let sample = HKStateOfMind(
            date: log.createdAt,
            kind: .momentaryEmotion,
            valence: mapping.valence,
            labels: mapping.labels,
            associations: [],
            metadata: [
                "OpenFeelingsLogID": log.id.uuidString,
                "OpenFeelingsEmotionPath": log.pathTitle
            ]
        )

        do {
            try await healthStore.save(sample)
            return .synced
        } catch {
            lastError = error.localizedDescription
            return .failed
        }
    }
}
