import Foundation

/// Subset of the iOS check-in flow settings that meaningfully shape the watch
/// wizard. iOS-only promoted dimensions (context, triggers, coping, mood,
/// strength) are intentionally omitted — the watch surface area is lean and
/// those steps don't have watch UIs yet.
struct WatchCheckInSettings: Codable, Sendable, Equatable {
    var bodyFirst: Bool
    var sensationsPromoted: Bool

    static let `default` = WatchCheckInSettings(bodyFirst: true, sensationsPromoted: false)

    // Stable WCSession applicationContext key. Bump only if we drop support
    // for the v1 dictionary shape — applicationContext keeps only the latest
    // value, so old senders would simply overwrite.
    static let userInfoKey = "checkInFlowSettings_v1"
}

extension WatchCheckInSettings {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    func applicationContext() throws -> [String: Any] {
        let data = try Self.encoder.encode(self)
        return [Self.userInfoKey: data]
    }

    static func decode(applicationContext: [String: Any]) -> WatchCheckInSettings? {
        guard let data = applicationContext[userInfoKey] as? Data else { return nil }
        return try? decoder.decode(WatchCheckInSettings.self, from: data)
    }
}
