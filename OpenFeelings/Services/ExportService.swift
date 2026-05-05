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
    // MARK: - CSV

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

    // MARK: - JSON

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

    // MARK: - Markdown

    /// Per-entry markdown — heading with emotion + time, dimensions as
    /// `**Label:**` lines, journal text as a blockquote. Used as the
    /// share-sheet payload and as a building block for the bundled export.
    static func markdown(log: FeelingLog,
                         calendar: Calendar = .current,
                         locale: Locale = .current) -> String {
        var lines: [String] = []

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.calendar = calendar
        timeFormatter.dateFormat = "h:mm a"

        let title = log.specificName.isEmpty ? log.secondaryName : log.specificName
        let displayTitle = title.isEmpty ? log.coreName : title
        lines.append("## \(displayTitle) · \(timeFormatter.string(from: log.createdAt))")

        let parts = [log.coreName, log.secondaryName, log.specificName]
            .filter { !$0.isEmpty }
        if parts.count > 1 {
            lines.append("*\(parts.dropLast().joined(separator: " → ")) → \(parts.last!)*")
        }
        lines.append("")

        if let intensity = log.intensity {
            lines.append("**Intensity:** \(intensity) / 5")
        }

        if let body = joinedDimension(log.bodyRegions.map(\.displayName.localizedLowercase),
                                       log.bodySensations.map(\.displayName.localizedLowercase)) {
            lines.append("**Body:** \(body)")
        }
        if let context = joinedDimension(log.contextPlaces.map(\.displayName.localizedLowercase),
                                          log.contextPeople.map(\.displayName.localizedLowercase)) {
            lines.append("**Context:** \(context)")
        }
        if let tc = joinedDimension(log.triggers.map(\.displayName.localizedLowercase),
                                     log.coping.map(\.displayName.localizedLowercase),
                                     separator: " → ") {
            lines.append("**Triggers / Coping:** \(tc)")
        }
        if let mood = moodSummary(for: log) {
            lines.append("**Mood:** \(mood)")
        }

        let trimmedNote = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty {
            lines.append("")
            for paragraph in trimmedNote.components(separatedBy: "\n") {
                lines.append("> \(paragraph)")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Bundled / date-range markdown — H1 with the date range, then one H2
    /// per day (descending) and one H3 per check-in within each day.
    static func markdown(logs: [FeelingLog],
                         calendar: Calendar = .current,
                         locale: Locale = .current) -> String {
        guard !logs.isEmpty else {
            return "# Open Feelings\n\nNo check-ins to export.\n"
        }

        let sorted = logs.sorted { $0.createdAt > $1.createdAt }
        let groups = Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.createdAt) }
        let dayKeysDescending = groups.keys.sorted(by: >)

        let rangeFormatter = DateFormatter()
        rangeFormatter.locale = locale
        rangeFormatter.calendar = calendar
        rangeFormatter.dateFormat = "MMMM d, yyyy"

        let firstDate = sorted.last!.createdAt
        let lastDate = sorted.first!.createdAt
        let rangeLabel: String
        if calendar.isDate(firstDate, inSameDayAs: lastDate) {
            rangeLabel = rangeFormatter.string(from: firstDate)
        } else {
            rangeFormatter.dateFormat = "MMM d"
            let from = rangeFormatter.string(from: firstDate)
            rangeFormatter.dateFormat = "MMM d, yyyy"
            let to = rangeFormatter.string(from: lastDate)
            rangeLabel = "\(from) – \(to)"
        }

        var output = ["# Open Feelings — \(rangeLabel)", ""]

        let dayHeading = DateFormatter()
        dayHeading.locale = locale
        dayHeading.calendar = calendar
        dayHeading.dateFormat = "EEEE, MMMM d, yyyy"

        for day in dayKeysDescending {
            output.append("## \(dayHeading.string(from: day))")
            output.append("")
            let dayLogs = groups[day] ?? []
            for log in dayLogs {
                // Per-entry block but use ### for sub-section under day H2.
                let entry = markdown(log: log, calendar: calendar, locale: locale)
                let bumped = entry.replacingOccurrences(of: "## ", with: "### ", options: [.anchored])
                output.append(bumped)
                output.append("")
                output.append("---")
                output.append("")
            }
        }

        // Trim the trailing "---\n\n".
        while output.last == "" || output.last == "---" {
            output.removeLast()
        }
        output.append("")
        return output.joined(separator: "\n")
    }

    /// Plain text — strip markdown syntax (#, **, ---, leading bullets, blockquote >)
    /// while preserving paragraph breaks. Useful when the share target renders
    /// markdown literally.
    static func plainText(log: FeelingLog,
                          calendar: Calendar = .current,
                          locale: Locale = .current) -> String {
        let md = markdown(log: log, calendar: calendar, locale: locale)
        return stripMarkdown(md)
    }

    static func plainText(logs: [FeelingLog],
                          calendar: Calendar = .current,
                          locale: Locale = .current) -> String {
        let md = markdown(logs: logs, calendar: calendar, locale: locale)
        return stripMarkdown(md)
    }

    // MARK: - Writers

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

    static func writeMarkdown(logs: [FeelingLog]) throws -> URL {
        let url = exportURL(extension: "md")
        try markdown(logs: logs).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func writePlainText(logs: [FeelingLog]) throws -> URL {
        let url = exportURL(extension: "txt")
        try plainText(logs: logs).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Internals

    private static func joinedDimension(_ a: [String],
                                         _ b: [String],
                                         separator: String = " · ") -> String? {
        let aPart = a.isEmpty ? "" : a.joined(separator: ", ")
        let bPart = b.isEmpty ? "" : b.joined(separator: ", ")
        switch (aPart.isEmpty, bPart.isEmpty) {
        case (true, true):   return nil
        case (false, true):  return aPart
        case (true, false):  return bPart
        case (false, false): return "\(aPart)\(separator)\(bPart)"
        }
    }

    private static func moodSummary(for log: FeelingLog) -> String? {
        let energy = log.moodEnergy.map { "energy \(MoodScale.energyBand($0))" }
        let valence = log.moodValence.map { "valence \(MoodScale.valenceBand($0))" }
        let parts = [energy, valence].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func stripMarkdown(_ md: String) -> String {
        var lines: [String] = []
        for raw in md.components(separatedBy: "\n") {
            var line = raw
            // Strip heading markers at start of line.
            while line.hasPrefix("#") { line.removeFirst() }
            line = line.trimmingCharacters(in: .whitespaces).description
            // Strip blockquote marker.
            if line.hasPrefix("> ") { line.removeFirst(2) }
            else if line == ">" { line = "" }
            // Strip horizontal rule.
            if line == "---" { line = "" }
            // Strip bold markers.
            line = line.replacingOccurrences(of: "**", with: "")
            // Strip italic markers used as a sub-title.
            if line.hasPrefix("*") && line.hasSuffix("*") && line.count > 2 {
                line = String(line.dropFirst().dropLast())
            }
            lines.append(line)
        }
        // Collapse repeated blank lines into a single blank.
        var collapsed: [String] = []
        var lastBlank = false
        for line in lines {
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank && lastBlank { continue }
            collapsed.append(line)
            lastBlank = isBlank
        }
        return collapsed.joined(separator: "\n")
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
