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
        case "anger":
            HealthStateOfMindMapping(valence: -0.72, labels: angerLabels(secondaryID: secondaryID))
        case "fear":
            HealthStateOfMindMapping(valence: -0.74, labels: fearLabels(secondaryID: secondaryID))
        case "sadness":
            HealthStateOfMindMapping(valence: -0.68, labels: sadnessLabels(secondaryID: secondaryID))
        case "shame":
            HealthStateOfMindMapping(valence: -0.7, labels: shameLabels(secondaryID: secondaryID))
        case "disgust":
            HealthStateOfMindMapping(valence: -0.62, labels: disgustLabels(secondaryID: secondaryID))
        case "joy":
            HealthStateOfMindMapping(valence: 0.78, labels: joyLabels(secondaryID: secondaryID))
        case "love":
            HealthStateOfMindMapping(valence: 0.8, labels: loveLabels(secondaryID: secondaryID))
        case "calm":
            HealthStateOfMindMapping(valence: 0.48, labels: calmLabels(secondaryID: secondaryID))
        default:
            HealthStateOfMindMapping(valence: 0, labels: [.indifferent])
        }
    }

    private static func angerLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "irritated": [.irritated, .annoyed]
        case "resentful": [.angry, .jealous]
        case "threatened": [.stressed, .worried]
        case "outraged": [.angry, .frustrated]
        default: [.angry]
        }
    }

    private static func fearLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "anxious": [.anxious, .worried]
        case "insecure": [.worried, .scared]
        case "helpless": [.overwhelmed, .scared]
        case "alarmed": [.scared, .stressed]
        default: [.scared]
        }
    }

    private static func sadnessLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "lonely": [.lonely, .sad]
        case "hurt": [.sad, .disappointed]
        case "grief": [.sad, .discouraged]
        case "low": [.drained, .discouraged]
        default: [.sad]
        }
    }

    private static func shameLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "embarrassed": [.embarrassed, .ashamed]
        case "guilty": [.guilty, .ashamed]
        case "unworthy": [.ashamed, .discouraged]
        case "vulnerable": [.ashamed, .worried]
        default: [.ashamed]
        }
    }

    private static func disgustLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "aversion": [.disgusted]
        case "contempt": [.disgusted, .angry]
        case "disappointed": [.disappointed, .discouraged]
        case "distrust": [.worried, .disappointed]
        default: [.disgusted]
        }
    }

    private static func joyLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "happy": [.happy, .joyful]
        case "proud": [.proud, .confident]
        case "grateful": [.grateful, .content]
        case "hopeful": [.hopeful, .excited]
        default: [.joyful]
        }
    }

    private static func loveLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "connected": [.content, .grateful]
        case "affectionate": [.peaceful, .content]
        case "compassionate": [.grateful, .calm]
        case "passionate": [.passionate, .excited]
        default: [.passionate]
        }
    }

    private static func calmLabels(secondaryID: String) -> [HKStateOfMind.Label] {
        switch secondaryID {
        case "peaceful": [.peaceful, .calm]
        case "content": [.content, .satisfied]
        case "present": [.calm, .content]
        case "rested": [.relieved, .satisfied]
        default: [.calm]
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
