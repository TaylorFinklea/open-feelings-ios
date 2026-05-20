import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings section: export the entire SwiftData store to a JSON backup
/// file, and import a previously-exported file (merge-only, dedup by
/// per-type key). Owns its own state for file picker, confirmation, and
/// summary alerts so `SettingsView` stays focused on its other concerns.
struct BackupSection: View {
    @Environment(\.modelContext) private var context

    @State private var showingFileExporter = false
    @State private var exportDocument: BackupDocument?
    @State private var exportError: String?

    @State private var showingFileImporter = false
    @State private var pendingImport: BackupEnvelope?
    @State private var importSummary: BackupService.ImportSummary?
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            OFSectionHeader(title: "Backup")
            VStack(spacing: 0) {
                Button(action: prepareExport) {
                    OFListRow.chevron(
                        title: "Export backup",
                        subtitle: "Save every entry to a JSON file.",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)
                divider
                Button {
                    showingFileImporter = true
                } label: {
                    OFListRow.chevron(
                        title: "Import backup",
                        subtitle: "Merge a backup file (no duplicates).",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(Color.OF.surface)
            .clipShape(RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
            .padding(.horizontal, CGFloat.OF.lg)

            Text("Backups stay on this device unless you share the file. They contain everything Open Feelings stores.")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CGFloat.OF.lg)
                .padding(.bottom, CGFloat.OF.md)
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultFilename()
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleFileImporter(result: result)
        }
        .alert("Export failed", isPresented: errorBinding($exportError)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .alert("Couldn't import backup", isPresented: errorBinding($importError)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert(
            "Import this backup?",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            )
        ) {
            Button("Import", role: .none) { performImport() }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text(pendingImportSummary)
        }
        .alert(
            "Import complete",
            isPresented: Binding(
                get: { importSummary != nil },
                set: { if !$0 { importSummary = nil } }
            )
        ) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(importSummaryMessage)
        }
    }

    // MARK: - Layout helpers

    private var divider: some View {
        Divider()
            .background(Color.OF.divider)
            .padding(.leading, CGFloat.OF.xxxl + .OF.sm)
    }

    private func errorBinding(_ source: Binding<String?>) -> Binding<Bool> {
        Binding(
            get: { source.wrappedValue != nil },
            set: { if !$0 { source.wrappedValue = nil } }
        )
    }

    // MARK: - Export

    private func prepareExport() {
        do {
            let envelope = try BackupService.encodeToEnvelope(context: context)
            exportDocument = BackupDocument(envelope: envelope)
            showingFileExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func defaultFilename() -> String {
        let stamp = Date().formatted(.iso8601
            .year().month().day()
            .dateSeparator(.dash)
            .timeSeparator(.colon)
            .time(includingFractionalSeconds: false))
        let safe = stamp.replacingOccurrences(of: ":", with: "-")
        return "OpenFeelings-backup-\(safe)"
    }

    // MARK: - Import

    private func handleFileImporter(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let needsScopedAccess = url.startAccessingSecurityScopedResource()
                defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                pendingImport = try BackupService.decodeEnvelope(from: data)
            } catch let error as BackupService.ImportError {
                importError = error.errorDescription
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            // User-cancelled fileImporter shows up here too; suppress that.
            let ns = error as NSError
            if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError { return }
            importError = error.localizedDescription
        }
    }

    private func performImport() {
        guard let envelope = pendingImport else { return }
        pendingImport = nil
        do {
            let summary = try BackupService.importBackup(from: envelope, into: context)
            importSummary = summary
        } catch let error as BackupService.ImportError {
            importError = error.errorDescription
        } catch {
            importError = error.localizedDescription
        }
    }

    private var pendingImportSummary: String {
        guard let envelope = pendingImport else { return "" }
        var lines: [String] = []
        func add(_ label: String, count: Int) {
            guard count > 0 else { return }
            lines.append("• \(count) \(count == 1 ? label : pluralize(label))")
        }
        add("check-in", count: envelope.feelingLogs.count)
        add("intention", count: envelope.intentions.count)
        add("thought record", count: envelope.thoughtRecords.count)
        add("value sort", count: envelope.valueSorts.count)
        add("committed action", count: envelope.committedActions.count)
        add("custom value", count: envelope.customValues.count)
        add("custom body region", count: envelope.customBodyRegions.count)
        add("body-map override file", count: envelope.userBodyMaps.count)

        let header = "From \(envelope.exportedAt.formatted(date: .abbreviated, time: .shortened)) (app \(envelope.appVersion))."
        let body = lines.isEmpty
            ? "The backup is empty — nothing to import."
            : lines.joined(separator: "\n")
        let footer = "Duplicates (same id, or same day for intentions) are skipped automatically."
        return "\(header)\n\n\(body)\n\n\(footer)"
    }

    private var importSummaryMessage: String {
        guard let summary = importSummary else { return "" }
        if summary.imported == 0 && summary.skipped == 0 {
            return "Nothing to import — the backup was empty."
        }
        var lines = ["Imported \(summary.imported) new, skipped \(summary.skipped) already present."]
        let breakdown = summary.perType
            .sorted { $0.key < $1.key }
            .compactMap { type, counts -> String? in
                guard counts.imported > 0 || counts.skipped > 0 else { return nil }
                return "• \(type): +\(counts.imported), skipped \(counts.skipped)"
            }
        if !breakdown.isEmpty {
            lines.append("")
            lines.append(contentsOf: breakdown)
        }
        return lines.joined(separator: "\n")
    }

    private func pluralize(_ singular: String) -> String {
        // Tiny English plural rule sufficient for the labels we use.
        if singular.hasSuffix("y") {
            return String(singular.dropLast()) + "ies"
        }
        return singular + "s"
    }
}

// MARK: - FileDocument

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    static let writableContentTypes: [UTType] = [.json]

    var envelope: BackupEnvelope

    init(envelope: BackupEnvelope) {
        self.envelope = envelope
    }

    init(configuration: ReadConfiguration) throws {
        // The export-only document never participates in document-based
        // open flows. Provide a stub init since FileDocument requires it.
        throw CocoaError(.fileReadUnknown)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try BackupService.jsonEncoder.encode(envelope)
        return FileWrapper(regularFileWithContents: data)
    }
}
