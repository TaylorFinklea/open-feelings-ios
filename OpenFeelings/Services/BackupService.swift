import Foundation
import SwiftData

/// Local backup and restore for every SwiftData `@Model` Open Feelings owns.
/// The file format is a single JSON `BackupEnvelope` containing arrays of
/// flat Codable mirrors of each model type — decoupling the wire format
/// from `@Model` internals so future schema changes can't break old backup
/// files.
///
/// Dedup keys on import:
/// - Most types: `id: UUID`.
/// - `Intention`: `date` (start-of-day) — one per day by design.
/// - `UserBodyMap`: singleton — if an existing record is present we skip
///   the imported one rather than merging the entries.
///
/// Merge-only by design. There's no "wipe and replace" path; users who
/// want a clean restore should delete the app and reinstall before
/// importing.
enum BackupService {

    /// Bump only when the envelope shape becomes incompatible with prior
    /// readers. Adding optional fields doesn't require a bump; removing
    /// fields or changing field types does. Imports refuse to read an
    /// envelope with a version higher than this constant.
    static let currentSchemaVersion = 1

    enum ImportError: Error, LocalizedError {
        case schemaVersionTooNew(have: Int, supported: Int)
        case decodeFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .schemaVersionTooNew(let have, let supported):
                return "This backup was made by a newer version of the app (schema \(have); this build supports up to \(supported))."
            case .decodeFailed:
                return "This file isn't a recognized Open Feelings backup."
            }
        }
    }

    struct ImportSummary: Equatable, Sendable {
        var imported: Int = 0
        var skipped: Int = 0
        var perType: [String: Counts] = [:]

        struct Counts: Equatable, Sendable {
            var imported: Int = 0
            var skipped: Int = 0
        }

        mutating func bump(_ type: String, imported delta: Int, skipped: Int) {
            self.imported += delta
            self.skipped += skipped
            var c = perType[type] ?? .init()
            c.imported += delta
            c.skipped += skipped
            perType[type] = c
        }
    }

    // MARK: - Encode

    /// Gather every row from `context` and build a `BackupEnvelope`. Pure;
    /// safe to call on the main actor. The caller is responsible for
    /// serializing to JSON and presenting the file to the user.
    @MainActor
    static func encodeToEnvelope(context: ModelContext) throws -> BackupEnvelope {
        BackupEnvelope(
            appVersion: Self.bundleAppVersion,
            schemaVersion: Self.currentSchemaVersion,
            exportedAt: Date(),
            feelingLogs: try context.fetch(FetchDescriptor<FeelingLog>()).map(BackupFeelingLog.init),
            intentions: try context.fetch(FetchDescriptor<Intention>()).map(BackupIntention.init),
            userBodyMaps: try context.fetch(FetchDescriptor<UserBodyMap>()).map(BackupUserBodyMap.init),
            customBodyRegions: try context.fetch(FetchDescriptor<CustomBodyRegion>()).map(BackupCustomBodyRegion.init),
            customValues: try context.fetch(FetchDescriptor<CustomValue>()).map(BackupCustomValue.init),
            valueSorts: try context.fetch(FetchDescriptor<ValueSort>()).map(BackupValueSort.init),
            committedActions: try context.fetch(FetchDescriptor<CommittedAction>()).map(BackupCommittedAction.init),
            thoughtRecords: try context.fetch(FetchDescriptor<ThoughtRecord>()).map(BackupThoughtRecord.init)
        )
    }

    @MainActor
    static func encodeToData(context: ModelContext) throws -> Data {
        let envelope = try encodeToEnvelope(context: context)
        return try jsonEncoder.encode(envelope)
    }

    // MARK: - Decode

    static func decodeEnvelope(from data: Data) throws -> BackupEnvelope {
        do {
            return try jsonDecoder.decode(BackupEnvelope.self, from: data)
        } catch {
            throw ImportError.decodeFailed(underlying: error)
        }
    }

    // MARK: - Import

    /// Merge `envelope` into `context`, skipping any row whose dedup key
    /// already exists locally. Returns a per-type summary so the caller
    /// can show "Imported X new, skipped Y already present."
    @MainActor
    static func importBackup(
        from envelope: BackupEnvelope,
        into context: ModelContext
    ) throws -> ImportSummary {
        if envelope.schemaVersion > currentSchemaVersion {
            throw ImportError.schemaVersionTooNew(
                have: envelope.schemaVersion,
                supported: currentSchemaVersion
            )
        }

        var summary = ImportSummary()

        // FeelingLog — dedup by id.
        try mergeByUUID(
            envelope.feelingLogs,
            type: "FeelingLog",
            into: context,
            existingIDs: { try context.fetch(FetchDescriptor<FeelingLog>()).map(\.id) },
            id: \.id,
            buildModel: { $0.toModel() },
            summary: &summary
        )

        // Intention — dedup by start-of-day date.
        let existingIntentionDates = Set(
            try context.fetch(FetchDescriptor<Intention>())
                .map { Calendar.current.startOfDay(for: $0.date) }
        )
        var importedIntentions = 0
        var skippedIntentions = 0
        for backup in envelope.intentions {
            let day = Calendar.current.startOfDay(for: backup.date)
            if existingIntentionDates.contains(day) {
                skippedIntentions += 1
            } else {
                context.insert(backup.toModel())
                importedIntentions += 1
            }
        }
        summary.bump("Intention", imported: importedIntentions, skipped: skippedIntentions)

        // UserBodyMap — singleton: skip the import if a row already exists.
        let existingUserBodyMaps = try context.fetch(FetchDescriptor<UserBodyMap>())
        if existingUserBodyMaps.isEmpty {
            for backup in envelope.userBodyMaps {
                context.insert(backup.toModel())
                summary.bump("UserBodyMap", imported: 1, skipped: 0)
            }
        } else {
            // Anything in the backup is treated as "already present."
            summary.bump("UserBodyMap", imported: 0, skipped: envelope.userBodyMaps.count)
        }

        // The rest dedup by UUID id.
        try mergeByUUID(
            envelope.customBodyRegions,
            type: "CustomBodyRegion",
            into: context,
            existingIDs: { try context.fetch(FetchDescriptor<CustomBodyRegion>()).map(\.id) },
            id: \.id,
            buildModel: { $0.toModel() },
            summary: &summary
        )
        try mergeByUUID(
            envelope.customValues,
            type: "CustomValue",
            into: context,
            existingIDs: { try context.fetch(FetchDescriptor<CustomValue>()).map(\.id) },
            id: \.id,
            buildModel: { $0.toModel() },
            summary: &summary
        )
        try mergeByUUID(
            envelope.valueSorts,
            type: "ValueSort",
            into: context,
            existingIDs: { try context.fetch(FetchDescriptor<ValueSort>()).map(\.id) },
            id: \.id,
            buildModel: { $0.toModel() },
            summary: &summary
        )
        try mergeByUUID(
            envelope.committedActions,
            type: "CommittedAction",
            into: context,
            existingIDs: { try context.fetch(FetchDescriptor<CommittedAction>()).map(\.id) },
            id: \.id,
            buildModel: { $0.toModel() },
            summary: &summary
        )
        try mergeByUUID(
            envelope.thoughtRecords,
            type: "ThoughtRecord",
            into: context,
            existingIDs: { try context.fetch(FetchDescriptor<ThoughtRecord>()).map(\.id) },
            id: \.id,
            buildModel: { $0.toModel() },
            summary: &summary
        )

        try context.save()
        return summary
    }

    @MainActor
    private static func mergeByUUID<Backup, Model>(
        _ backups: [Backup],
        type: String,
        into context: ModelContext,
        existingIDs: () throws -> [UUID],
        id: KeyPath<Backup, UUID>,
        buildModel: (Backup) -> Model,
        summary: inout ImportSummary
    ) throws where Model: PersistentModel {
        let existing = Set(try existingIDs())
        var imported = 0
        var skipped = 0
        for backup in backups {
            if existing.contains(backup[keyPath: id]) {
                skipped += 1
            } else {
                context.insert(buildModel(backup))
                imported += 1
            }
        }
        summary.bump(type, imported: imported, skipped: skipped)
    }

    // MARK: - JSON

    /// Use milliseconds-since-1970 for dates so encode → decode round-trips
    /// without precision loss. Slightly less human-readable than ISO8601 but
    /// the file isn't meant to be edited by hand.
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }()

    private static var bundleAppVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}

// MARK: - Envelope

struct BackupEnvelope: Codable, Equatable, Sendable {
    var appVersion: String
    var schemaVersion: Int
    var exportedAt: Date
    var feelingLogs: [BackupFeelingLog]
    var intentions: [BackupIntention]
    var userBodyMaps: [BackupUserBodyMap]
    var customBodyRegions: [BackupCustomBodyRegion]
    var customValues: [BackupCustomValue]
    var valueSorts: [BackupValueSort]
    var committedActions: [BackupCommittedAction]
    var thoughtRecords: [BackupThoughtRecord]
}

// MARK: - Per-model mirrors

struct BackupFeelingLog: Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var coreID: String
    var coreName: String
    var secondaryID: String
    var secondaryName: String
    var specificID: String
    var specificName: String
    var intensity: Int?
    var note: String
    var healthSyncStatusRaw: String
    var bodyRegionsRaw: String
    var customBodyRegionIDsRaw: String
    var bodySensationsRaw: String
    var contextPlacesRaw: String
    var contextPeopleRaw: String
    var triggersRaw: String
    var copingRaw: String
    var moodEnergy: Double?
    var moodValence: Double?
    var captureSource: String

    init(_ log: FeelingLog) {
        self.id = log.id
        self.createdAt = log.createdAt
        self.coreID = log.coreID
        self.coreName = log.coreName
        self.secondaryID = log.secondaryID
        self.secondaryName = log.secondaryName
        self.specificID = log.specificID
        self.specificName = log.specificName
        self.intensity = log.intensity
        self.note = log.note
        self.healthSyncStatusRaw = log.healthSyncStatusRaw
        self.bodyRegionsRaw = log.bodyRegionsRaw
        self.customBodyRegionIDsRaw = log.customBodyRegionIDsRaw
        self.bodySensationsRaw = log.bodySensationsRaw
        self.contextPlacesRaw = log.contextPlacesRaw
        self.contextPeopleRaw = log.contextPeopleRaw
        self.triggersRaw = log.triggersRaw
        self.copingRaw = log.copingRaw
        self.moodEnergy = log.moodEnergy
        self.moodValence = log.moodValence
        self.captureSource = log.captureSource
    }

    func toModel() -> FeelingLog {
        let log = FeelingLog(
            id: id,
            createdAt: createdAt,
            coreID: coreID,
            coreName: coreName,
            secondaryID: secondaryID,
            secondaryName: secondaryName,
            specificID: specificID,
            specificName: specificName,
            intensity: intensity,
            note: note,
            healthSyncStatus: HealthSyncStatus(rawValue: healthSyncStatusRaw) ?? .notRequested,
            captureSource: captureSource
        )
        log.bodyRegionsRaw = bodyRegionsRaw
        log.customBodyRegionIDsRaw = customBodyRegionIDsRaw
        log.bodySensationsRaw = bodySensationsRaw
        log.contextPlacesRaw = contextPlacesRaw
        log.contextPeopleRaw = contextPeopleRaw
        log.triggersRaw = triggersRaw
        log.copingRaw = copingRaw
        log.moodEnergy = moodEnergy
        log.moodValence = moodValence
        return log
    }
}

struct BackupIntention: Codable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var text: String
    var reflection: String

    init(_ intention: Intention) {
        self.id = intention.id
        self.date = intention.date
        self.text = intention.text
        self.reflection = intention.reflection
    }

    func toModel() -> Intention {
        Intention(id: id, date: date, text: text, reflection: reflection)
    }
}

struct BackupUserBodyMap: Codable, Equatable, Sendable {
    var entriesRaw: String

    init(_ map: UserBodyMap) {
        self.entriesRaw = map.entriesRaw
    }

    func toModel() -> UserBodyMap {
        let map = UserBodyMap()
        map.entriesRaw = entriesRaw
        return map
    }
}

struct BackupCustomBodyRegion: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(_ region: CustomBodyRegion) {
        self.id = region.id
        self.name = region.name
        self.createdAt = region.createdAt
    }

    func toModel() -> CustomBodyRegion {
        CustomBodyRegion(id: id, name: name, createdAt: createdAt)
    }
}

struct BackupCustomValue: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(_ value: CustomValue) {
        self.id = value.id
        self.name = value.name
        self.createdAt = value.createdAt
    }

    func toModel() -> CustomValue {
        CustomValue(id: id, name: name, createdAt: createdAt)
    }
}

struct BackupValueSort: Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var bucketAssignmentsRaw: String
    var rankedTopRaw: String

    init(_ sort: ValueSort) {
        self.id = sort.id
        self.createdAt = sort.createdAt
        self.bucketAssignmentsRaw = sort.bucketAssignmentsRaw
        self.rankedTopRaw = sort.rankedTopRaw
    }

    func toModel() -> ValueSort {
        let sort = ValueSort(id: id, createdAt: createdAt)
        sort.bucketAssignmentsRaw = bucketAssignmentsRaw
        sort.rankedTopRaw = rankedTopRaw
        return sort
    }
}

struct BackupCommittedAction: Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var title: String
    var valueRef: String
    var whatsHard: String
    var isDone: Bool
    var completedAt: Date?
    var reflection: String

    init(_ action: CommittedAction) {
        self.id = action.id
        self.createdAt = action.createdAt
        self.title = action.title
        self.valueRef = action.valueRef
        self.whatsHard = action.whatsHard
        self.isDone = action.isDone
        self.completedAt = action.completedAt
        self.reflection = action.reflection
    }

    func toModel() -> CommittedAction {
        let action = CommittedAction(
            id: id,
            createdAt: createdAt,
            title: title,
            valueRef: valueRef,
            whatsHard: whatsHard
        )
        action.isDone = isDone
        action.completedAt = completedAt
        action.reflection = reflection
        return action
    }
}

struct BackupThoughtRecord: Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var situation: String
    var automaticThought: String
    var intensityBefore: Int?
    var patternsRaw: String
    var balancedThought: String
    var intensityAfter: Int?
    var linkedLogID: UUID?

    init(_ record: ThoughtRecord) {
        self.id = record.id
        self.createdAt = record.createdAt
        self.situation = record.situation
        self.automaticThought = record.automaticThought
        self.intensityBefore = record.intensityBefore
        self.patternsRaw = record.patternsRaw
        self.balancedThought = record.balancedThought
        self.intensityAfter = record.intensityAfter
        self.linkedLogID = record.linkedLogID
    }

    func toModel() -> ThoughtRecord {
        let record = ThoughtRecord(
            id: id,
            createdAt: createdAt,
            situation: situation,
            automaticThought: automaticThought,
            intensityBefore: intensityBefore,
            balancedThought: balancedThought,
            intensityAfter: intensityAfter,
            linkedLogID: linkedLogID
        )
        record.patternsRaw = patternsRaw
        return record
    }
}
