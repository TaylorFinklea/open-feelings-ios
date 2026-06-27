// OpenFeelings/NaturalLanguage/PendingQuickEntryStore.swift
import Foundation

/// Hands a pending utterance from the Siri intent (when it couldn't resolve a
/// feeling) to the app, which consumes it on launch/foreground and opens
/// QuickEntry pre-filled. Durable (UserDefaults) because the Shortcut may run
/// in a different process / cold-launch the app.
struct PendingQuickEntryStore {
    private let defaults: UserDefaults
    private let key = "pendingQuickEntryNote"

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
