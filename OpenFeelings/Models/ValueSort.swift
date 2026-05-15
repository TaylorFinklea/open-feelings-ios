import Foundation
import SwiftData

/// Which bucket a value was sorted into during Phase 1 of the card sort.
enum SortBucket: String, Codable, Sendable, CaseIterable {
    case veryImportant
    case important
    case notForMe
}

/// One completed value sort. Newest sort by `createdAt` is the active set;
/// older ones are retained as read-only history. Refs are strings:
/// `"family"` for curated entries, `"custom:<uuid>"` for `CustomValue`.
@Model
final class ValueSort {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// JSON-encoded `[String: String]` (refs → SortBucket.rawValue).
    /// String storage matches `bodyRegionsRaw` precedent on `FeelingLog`
    /// and avoids CloudKit limitations around typed dictionaries.
    var bucketAssignmentsRaw: String = "{}"

    /// JSON-encoded `[String]` — ordered finalists, position 0 = #1 rank.
    var rankedTopRaw: String = "[]"

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         bucketAssignments: [String: SortBucket] = [:],
         rankedTop: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.bucketAssignmentsRaw = Self.encodeAssignments(bucketAssignments)
        self.rankedTopRaw = Self.encodeRanked(rankedTop)
    }
}

extension ValueSort {
    var bucketAssignments: [String: SortBucket] {
        get { Self.decodeAssignments(bucketAssignmentsRaw) }
        set { bucketAssignmentsRaw = Self.encodeAssignments(newValue) }
    }

    var rankedTop: [String] {
        get { Self.decodeRanked(rankedTopRaw) }
        set { rankedTopRaw = Self.encodeRanked(newValue) }
    }

    static func encodeAssignments(_ dict: [String: SortBucket]) -> String {
        let raw = dict.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(raw),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    static func decodeAssignments(_ raw: String) -> [String: SortBucket] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded.compactMapValues { SortBucket(rawValue: $0) }
    }

    static func encodeRanked(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let s = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return s
    }

    static func decodeRanked(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }
}
