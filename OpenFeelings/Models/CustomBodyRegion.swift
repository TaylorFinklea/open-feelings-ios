import Foundation
import SwiftData

/// User-defined body region. Lives alongside the built-in `BodyRegion` enum
/// so users can log feelings in idiosyncratic places ("left arm", "jaw") that
/// don't fit the curated set. CloudKit-synced through the same private DB
/// as `FeelingLog`, so a user's custom regions follow them across devices.
@Model
final class CustomBodyRegion {
    /// Stable identifier referenced from `FeelingLog.customBodyRegionIDsRaw`
    /// and from learning aggregates. Survives renames.
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

extension CustomBodyRegion {
    /// Sort by creation order so the chip layout is stable across launches.
    static func sortedByCreation(_ regions: [CustomBodyRegion]) -> [CustomBodyRegion] {
        regions.sorted { $0.createdAt < $1.createdAt }
    }
}
