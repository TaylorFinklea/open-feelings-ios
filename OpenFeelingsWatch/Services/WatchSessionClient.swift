import Foundation
import Observation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
@Observable
final class WatchSessionClient: NSObject {
    private(set) var pendingCount: Int = 0
    private(set) var lastSendError: String?
    weak var settingsStore: WatchSettingsStore?

    private var pendingTransfers: [UUID: TransferRecord] = [:]
    private let queueURL: URL

    private struct TransferRecord {
        let payload: WatchCheckInPayload
    }

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.queueURL = support.appendingPathComponent("WatchSendQueue.json")
        super.init()
        loadQueue()
        activate()
    }

    private func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        // Seed settings from the cached applicationContext so cold launches
        // before iOS is reachable still get a non-default flow if one was
        // previously delivered.
        if let cached = WatchCheckInSettings.decode(applicationContext: session.receivedApplicationContext) {
            settingsStore?.update(cached)
        }
        #endif
    }

    func send(_ payload: WatchCheckInPayload) {
        appendToQueue(payload)
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        do {
            let info = try payload.userInfoDictionary()
            _ = WCSession.default.transferUserInfo(info)
            pendingTransfers[payload.id] = TransferRecord(payload: payload)
            lastSendError = nil
        } catch {
            lastSendError = error.localizedDescription
        }
        #endif
    }

    private func appendToQueue(_ payload: WatchCheckInPayload) {
        var queue = readQueue()
        queue.removeAll { $0.id == payload.id }
        queue.append(payload)
        writeQueue(queue)
        pendingCount = queue.count
    }

    private func removeFromQueue(id: UUID) {
        var queue = readQueue()
        queue.removeAll { $0.id == id }
        writeQueue(queue)
        pendingCount = queue.count
    }

    private func readQueue() -> [WatchCheckInPayload] {
        guard let data = try? Data(contentsOf: queueURL) else { return [] }
        return (try? WatchCheckInPayload.decoder.decode([WatchCheckInPayload].self, from: data)) ?? []
    }

    private func writeQueue(_ queue: [WatchCheckInPayload]) {
        guard let data = try? WatchCheckInPayload.encoder.encode(queue) else { return }
        try? data.write(to: queueURL, options: [.atomic])
    }

    private func loadQueue() {
        pendingCount = readQueue().count
    }
}

#if canImport(WatchConnectivity)
extension WatchSessionClient: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let settings = WatchCheckInSettings.decode(applicationContext: applicationContext) else { return }
        Task { @MainActor [weak self] in
            self?.settingsStore?.update(settings)
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let userInfo = userInfoTransfer.userInfo
        guard let payload = WatchCheckInPayload.decode(userInfo: userInfo) else { return }
        let payloadID = payload.id
        let failed = error != nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            if failed {
                // Keep in queue so the user sees it still pending; transferUserInfo retries automatically.
                self.lastSendError = error?.localizedDescription
            } else {
                self.removeFromQueue(id: payloadID)
                self.pendingTransfers.removeValue(forKey: payloadID)
            }
        }
    }
}
#endif
