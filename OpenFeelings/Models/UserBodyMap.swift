import Foundation
import SwiftData

/// One Codable row of user-overridden body→core mapping.
struct UserBodyMapEntry: Codable, Hashable, Sendable {
    let regionRaw: String      // BodyRegion.rawValue
    let coreIDs: [String]      // EmotionCore.id values, 1+
}

/// A user's explicit overrides of the curated body→core map. Stored as a
/// SwiftData `@Model` so changes sync via CloudKit alongside `FeelingLog`
/// and `Intention`. Single instance per user (matching the singleton-record
/// pattern used elsewhere).
@Model
final class UserBodyMap {
    /// Encoded entries. Stored as a serialized JSON String because SwiftData
    /// + CloudKit doesn't accept `[Codable]` directly.
    var entriesRaw: String = "[]"

    init() {}

    /// Decoded view. Recomputed each access; writes go through `setOverride`.
    var entries: [UserBodyMapEntry] {
        get {
            guard let data = entriesRaw.data(using: .utf8),
                  let list = try? JSONDecoder().decode([UserBodyMapEntry].self, from: data) else {
                return []
            }
            return list
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
            entriesRaw = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    func coreIDs(for region: BodyRegion) -> [String]? {
        entries.first(where: { $0.regionRaw == region.rawValue })?.coreIDs
    }

    func setOverride(for region: BodyRegion, coreIDs: [String]) {
        var current = entries.filter { $0.regionRaw != region.rawValue }
        current.append(UserBodyMapEntry(regionRaw: region.rawValue, coreIDs: coreIDs))
        entries = current
    }

    func clearOverride(for region: BodyRegion) {
        entries = entries.filter { $0.regionRaw != region.rawValue }
    }

    func resetAll() {
        entries = []
    }
}
