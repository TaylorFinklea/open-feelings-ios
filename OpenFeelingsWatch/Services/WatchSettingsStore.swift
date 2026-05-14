import Foundation
import Observation

/// Observable holder for the latest flow settings pushed from iOS. WCSession
/// caches the most recent applicationContext on disk, so on cold launch we
/// can seed the store synchronously without waiting for iOS to be reachable.
@MainActor
@Observable
final class WatchSettingsStore {
    private(set) var settings: WatchCheckInSettings = .default

    func update(_ new: WatchCheckInSettings) {
        settings = new
    }
}
