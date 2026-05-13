import Foundation

struct WatchCheckInPayload: Codable, Sendable, Equatable {
    var schemaVersion: Int
    let id: UUID
    let createdAt: Date
    let coreID: String
    let coreName: String
    let intensity: Int?
    let note: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        coreID: String,
        coreName: String,
        intensity: Int? = nil,
        note: String? = nil,
        schemaVersion: Int = WatchCheckInPayload.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.coreID = coreID
        self.coreName = coreName
        self.intensity = intensity
        self.note = note
    }

    static let currentSchemaVersion = 1

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
