// OpenFeelingsWatch/Services/PendingWatchEntryStore.swift
import Foundation

/// Hands a pending utterance from the watch Siri intent (when no emotion
/// resolved) to the watch app, which consumes it on launch/foreground and
/// opens the check-in flow pre-seeded. The watch intent + app share one
/// process, so plain UserDefaults.standard suffices. Mirrors iOS
/// PendingQuickEntryStore.
struct PendingWatchEntryStore {
    private let defaults: UserDefaults
    private let key = "pendingWatchEntryNote"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func stash(_ note: String) {
        defaults.set(note, forKey: key)
    }

    /// Returns the pending note and clears it (read-once).
    func take() -> String? {
        guard let note = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return note
    }
}
