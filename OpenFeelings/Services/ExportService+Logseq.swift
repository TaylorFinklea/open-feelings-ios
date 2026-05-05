import Foundation

/// Logseq journal-format export. One bullet block per check-in with `key:: value`
/// properties; body / context / triggers / coping wrap individual values in
/// `[[double-bracket]]` page-link tags so they become first-class graph pages.
/// Output is grouped under H1 day headings — the user can split the file into
/// matching `journals/YYYY_MM_DD.md` pages or paste each day into Logseq.
extension ExportService {
    static func logseq(logs: [FeelingLog],
                       calendar: Calendar = .current,
                       locale: Locale = .current) -> String {
        guard !logs.isEmpty else {
            return "# Open Feelings\n\nNo check-ins to export.\n"
        }

        let sorted = logs.sorted { $0.createdAt > $1.createdAt }
        let groups = Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.createdAt) }
        let dayKeysDescending = groups.keys.sorted(by: >)

        let dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.calendar = calendar
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let dayNameFormatter = DateFormatter()
        dayNameFormatter.locale = locale
        dayNameFormatter.calendar = calendar
        dayNameFormatter.dateFormat = "EEEE"

        let createdAtFormatter = ISO8601DateFormatter()
        createdAtFormatter.formatOptions = [.withInternetDateTime]

        var output: [String] = []

        for day in dayKeysDescending {
            output.append("# \(dayFormatter.string(from: day)) (\(dayNameFormatter.string(from: day)))")
            output.append("")

            for log in groups[day] ?? [] {
                let parts = [log.coreName, log.secondaryName, log.specificName]
                    .filter { !$0.isEmpty }
                let title: String
                if parts.count > 1 {
                    let display = log.specificName.isEmpty ? log.secondaryName : log.specificName
                    let path = parts.dropLast().joined(separator: " → ")
                    title = "\(display) (\(path) → \(parts.last!))"
                } else {
                    title = parts.first ?? "Check-in"
                }

                output.append("- ## \(title)")
                output.append("  created-at:: \(createdAtFormatter.string(from: log.createdAt))")
                if let intensity = log.intensity {
                    output.append("  intensity:: \(intensity)")
                }
                if !log.coreName.isEmpty {
                    output.append("  core:: \(logseqTag(log.coreName))")
                }

                let body = log.bodyRegions.map(\.displayName) + log.bodySensations.map(\.displayName)
                if !body.isEmpty {
                    output.append("  body:: \(body.map(logseqTag).joined(separator: ", "))")
                }

                let context = log.contextPlaces.map(\.displayName) + log.contextPeople.map(\.displayName)
                if !context.isEmpty {
                    output.append("  context:: \(context.map(logseqTag).joined(separator: ", "))")
                }

                if !log.triggers.isEmpty {
                    let tags = log.triggers.map { logseqTag($0.displayName) }
                    output.append("  triggers:: \(tags.joined(separator: ", "))")
                }
                if !log.coping.isEmpty {
                    let tags = log.coping.map { logseqTag($0.displayName) }
                    output.append("  coping:: \(tags.joined(separator: ", "))")
                }
                if let energy = log.moodEnergy {
                    output.append("  mood-energy:: \(MoodScale.energyBand(energy))")
                }
                if let valence = log.moodValence {
                    output.append("  mood-valence:: \(MoodScale.valenceBand(valence))")
                }

                let trimmedNote = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedNote.isEmpty {
                    output.append("  - **Journal**")
                    for paragraph in trimmedNote.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        output.append("    - \(trimmed)")
                    }
                }
            }

            output.append("")
        }

        return output.joined(separator: "\n")
    }

    static func writeLogseq(logs: [FeelingLog]) throws -> URL {
        let url = logseqExportURL()
        try logseq(logs: logs).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Wraps a display name in Logseq's `[[page-link]]` syntax with kebab-case.
    private static func logseqTag(_ name: String) -> String {
        let kebab = name
            .lowercased()
            .replacingOccurrences(of: "/", with: "-")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "[[\(kebab)]]"
    }

    /// Logseq files conventionally use `.md`. Match the markdown export's
    /// file-naming pattern but mark the contents as Logseq via the suffix.
    private static func logseqExportURL() -> URL {
        let stamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        return FileManager.default.temporaryDirectory
            .appendingPathComponent("open-feelings-logseq-\(stamp)")
            .appendingPathExtension("md")
    }
}
