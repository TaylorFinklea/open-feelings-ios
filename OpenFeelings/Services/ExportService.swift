import Foundation

struct FeelingLogExport: Codable {
    let id: UUID
    let createdAt: Date
    let core: String
    let secondary: String
    let specific: String
    let intensity: Int?
    let note: String
}

enum ExportService {
    static func csv(logs: [FeelingLog]) -> String {
        var rows = [
            ["id", "created_at", "core", "secondary", "specific", "intensity", "note"]
        ]

        rows += logs.map { log in
            [
                log.id.uuidString,
                ISO8601DateFormatter().string(from: log.createdAt),
                log.coreName,
                log.secondaryName,
                log.specificName,
                log.intensity.map(String.init) ?? "",
                log.note
            ]
        }

        return rows
            .map { $0.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n")
            + "\n"
    }

    static func jsonData(logs: [FeelingLog]) throws -> Data {
        let payload = logs.map { log in
            FeelingLogExport(
                id: log.id,
                createdAt: log.createdAt,
                core: log.coreName,
                secondary: log.secondaryName,
                specific: log.specificName,
                intensity: log.intensity,
                note: log.note
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func writeCSV(logs: [FeelingLog]) throws -> URL {
        let url = exportURL(extension: "csv")
        try csv(logs: logs).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func writeJSON(logs: [FeelingLog]) throws -> URL {
        let url = exportURL(extension: "json")
        try jsonData(logs: logs).write(to: url, options: .atomic)
        return url
    }

    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        } else {
            field
        }
    }

    private static func exportURL(extension pathExtension: String) -> URL {
        let stamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        return FileManager.default.temporaryDirectory
            .appendingPathComponent("open-feelings-\(stamp)")
            .appendingPathExtension(pathExtension)
    }
}
