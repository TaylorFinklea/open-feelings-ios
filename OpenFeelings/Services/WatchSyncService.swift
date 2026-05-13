import Foundation
import SwiftData
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
final class WatchSyncService: NSObject {
    private weak var healthService: HealthService?
    private var modelContainer: ModelContainer?
    private var bufferedPayloads: [WatchCheckInPayload] = []

    private var isHealthEnabled: Bool {
        UserDefaults.standard.bool(forKey: "healthEnabled")
    }

    init(healthService: HealthService) {
        self.healthService = healthService
        super.init()
        activateSessionIfSupported()
    }

    func attach(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        flushBuffer()
    }

    private func activateSessionIfSupported() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
    }

    func ingest(_ payload: WatchCheckInPayload) {
        guard let container = modelContainer else {
            bufferedPayloads.append(payload)
            return
        }
        let context = ModelContext(container)
        if logExists(id: payload.id, in: context) { return }
        let log = makeFeelingLog(from: payload)
        context.insert(log)
        try? context.save()

        if let healthService {
            let enabled = isHealthEnabled
            Task { @MainActor in
                let status = await healthService.save(log: log, isEnabled: enabled)
                log.healthSyncStatus = status
                try? context.save()
            }
        }
    }

    private func flushBuffer() {
        guard modelContainer != nil else { return }
        let pending = bufferedPayloads
        bufferedPayloads.removeAll(keepingCapacity: false)
        for payload in pending { ingest(payload) }
    }

    private func logExists(id: UUID, in context: ModelContext) -> Bool {
        let predicate = #Predicate<FeelingLog> { $0.id == id }
        let descriptor = FetchDescriptor<FeelingLog>(predicate: predicate)
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    // Maps a watch payload (which may stop at any feeling-drill level and may
    // include body regions/sensations) into a full `FeelingLog`. Unknown body
    // tokens are dropped silently via the BodyRegion/BodySensation parse helpers
    // so a schema drift between watch and phone can't crash the receive path.
    func makeFeelingLog(from payload: WatchCheckInPayload) -> FeelingLog {
        let initialHealthStatus: HealthSyncStatus = isHealthEnabled ? .pending : .notRequested
        let trimmedNote = payload.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let regions = payload.bodyRegions.compactMap(BodyRegion.init(rawValue:))
        let sensations = payload.bodySensations.compactMap(BodySensation.init(rawValue:))
        return FeelingLog(
            id: payload.id,
            createdAt: payload.createdAt,
            coreID: payload.coreID,
            coreName: payload.coreName,
            secondaryID: payload.secondaryID ?? "",
            secondaryName: payload.secondaryName ?? "",
            specificID: payload.specificID ?? "",
            specificName: payload.specificName ?? "",
            intensity: payload.intensity,
            note: trimmedNote,
            healthSyncStatus: initialHealthStatus,
            bodyRegions: regions,
            bodySensations: sensations,
            captureSource: "watch"
        )
    }
}

#if canImport(WatchConnectivity)
extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // No-op: errors here aren't actionable; transferUserInfo retries on its own.
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate to support switching paired watches.
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let payload = WatchCheckInPayload.decode(userInfo: userInfo) else { return }
        Task { @MainActor [weak self] in
            self?.ingest(payload)
        }
    }
}
#endif
