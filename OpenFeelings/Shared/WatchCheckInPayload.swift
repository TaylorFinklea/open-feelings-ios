import Foundation

struct WatchCheckInPayload: Codable, Sendable, Equatable {
    var schemaVersion: Int
    let id: UUID
    let createdAt: Date
    let coreID: String
    let coreName: String
    let secondaryID: String?
    let secondaryName: String?
    let specificID: String?
    let specificName: String?
    let intensity: Int?
    let bodyRegions: [String]
    let bodySensations: [String]
    let note: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        coreID: String,
        coreName: String,
        secondaryID: String? = nil,
        secondaryName: String? = nil,
        specificID: String? = nil,
        specificName: String? = nil,
        intensity: Int? = nil,
        bodyRegions: [String] = [],
        bodySensations: [String] = [],
        note: String? = nil,
        schemaVersion: Int = WatchCheckInPayload.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.coreID = coreID
        self.coreName = coreName
        self.secondaryID = secondaryID
        self.secondaryName = secondaryName
        self.specificID = specificID
        self.specificName = specificName
        self.intensity = intensity
        self.bodyRegions = bodyRegions
        self.bodySensations = bodySensations
        self.note = note
    }

    // v1 payloads pre-date secondary/specific/body fields. We keep decoding them
    // by defaulting missing keys to nil/empty so a watch still on v1 (with queued
    // entries) can drain to a v2 phone without loss.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        coreID = try c.decode(String.self, forKey: .coreID)
        coreName = try c.decode(String.self, forKey: .coreName)
        secondaryID = try c.decodeIfPresent(String.self, forKey: .secondaryID)
        secondaryName = try c.decodeIfPresent(String.self, forKey: .secondaryName)
        specificID = try c.decodeIfPresent(String.self, forKey: .specificID)
        specificName = try c.decodeIfPresent(String.self, forKey: .specificName)
        intensity = try c.decodeIfPresent(Int.self, forKey: .intensity)
        bodyRegions = try c.decodeIfPresent([String].self, forKey: .bodyRegions) ?? []
        bodySensations = try c.decodeIfPresent([String].self, forKey: .bodySensations) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    static let currentSchemaVersion = 2

    // Stable WCSession userInfo dictionary key. Do not bump unless we drop
    // support for queued payloads from older watch builds — that's destructive.
    static let userInfoVersionKey = "v1"
}

extension WatchCheckInPayload {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func userInfoDictionary() throws -> [String: Any] {
        let data = try Self.encoder.encode(self)
        return [Self.userInfoVersionKey: data]
    }

    static func decode(userInfo: [String: Any]) -> WatchCheckInPayload? {
        guard let data = userInfo[userInfoVersionKey] as? Data else { return nil }
        return try? decoder.decode(WatchCheckInPayload.self, from: data)
    }
}
