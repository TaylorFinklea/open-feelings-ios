import SwiftData
import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var allLogs: [FeelingLog]

    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var pendingDelete: FeelingLog?

    private var logs: [FeelingLog] {
        guard let filter = navigation.historyFilter else { return allLogs }
        switch filter {
        case .secondaryName(let name):
            return allLogs.filter { $0.secondaryName == name }
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
            .navigationTitle("History")
            .safeAreaInset(edge: .top) {
                if let filter = navigation.historyFilter {
                    filterBanner(filter)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { exportMarkdown() } label: {
                            Label("Export Markdown", systemImage: "doc.richtext")
                        }
                        Button { exportPlainText() } label: {
                            Label("Export Plain Text", systemImage: "doc.text")
                        }
                        Button { exportLogseq() } label: {
                            Label("Export Logseq", systemImage: "list.bullet.indent")
                        }
                        Divider()
                        Button { exportCSV() } label: {
                            Label("Export CSV", systemImage: "tablecells")
                        }
                        Button { exportJSON() } label: {
                            Label("Export JSON", systemImage: "curlybraces")
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(logs.isEmpty)
                    .tint(Color.OF.accent)
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityView(items: [item.url])
            }
            .alert("Delete this check-in?", isPresented: deleteAlertBinding) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let log = pendingDelete {
                        Self.deleteLog(log, in: modelContext)
                    }
                    pendingDelete = nil
                }
            } message: {
                Text("This permanently removes the entry from this device and any iCloud-synced devices.")
            }
            .alert("Export failed", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if logs.isEmpty {
            OFEmptyState(
                glyph: "tray",
                title: navigation.historyFilter == nil
                    ? "No check-ins yet"
                    : "No check-ins match this filter",
                bodyText: navigation.historyFilter == nil
                    ? "Check-ins you save will show up here."
                    : "Try clearing the filter to see all entries."
            )
        } else {
            ScrollView {
                VStack(spacing: .OF.md) {
                    ForEach(logs) { log in
                        OFCard { LogCard(log: log) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = log
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .accessibilityAction(named: "Delete") {
                                pendingDelete = log
                            }
                    }
                }
                .padding(.horizontal, CGFloat.OF.lg)
                .padding(.bottom, CGFloat.OF.xxxl)
                .padding(.top, CGFloat.OF.lg)
            }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    @ViewBuilder
    private func filterBanner(_ filter: HistoryFilter) -> some View {
        HStack(spacing: .OF.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(Color.OF.accent)
            Text("Showing: \(filter.displayLabel)")
                .font(.OF.bodyEmphasis)
                .foregroundStyle(Color.OF.text)
            Spacer()
            Button {
                navigation.clearHistoryFilter()
            } label: {
                Text("Clear")
                    .font(.OF.bodyEmphasis)
                    .foregroundStyle(Color.OF.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history.clearFilter")
        }
        .padding(.horizontal, CGFloat.OF.lg)
        .padding(.vertical, CGFloat.OF.sm)
        .background(.thinMaterial)
    }

    private func exportCSV() {
        do {
            shareItem = ShareItem(url: try ExportService.writeCSV(logs: logs))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportJSON() {
        do {
            shareItem = ShareItem(url: try ExportService.writeJSON(logs: logs))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportMarkdown() {
        do {
            shareItem = ShareItem(url: try ExportService.writeMarkdown(logs: logs))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportPlainText() {
        do {
            shareItem = ShareItem(url: try ExportService.writePlainText(logs: logs))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportLogseq() {
        do {
            shareItem = ShareItem(url: try ExportService.writeLogseq(logs: logs))
        } catch {
            exportError = error.localizedDescription
        }
    }
}

extension HistoryView {
    static func deleteLog(_ log: FeelingLog, in context: ModelContext) {
        context.delete(log)
        try? context.save()
    }
}

struct LogCard: View {
    let log: FeelingLog

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            cardContent
            shareMenu
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(log.emotionTitle)
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Spacer()
                Text(log.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.OF.mono)
                    .foregroundStyle(Color.OF.textMuted)
            }

            Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                .font(.OF.body)
                .foregroundStyle(Color.OF.textMuted)

            HStack(spacing: .OF.md) {
                if let intensity = log.intensity {
                    intensityDots(intensity: intensity)
                    Text("\(intensity)/5")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
                Label(log.healthSyncStatus.label, systemImage: "heart.text.square")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            if let summary = bodySummary(for: log) {
                Text(summary)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            if let context = contextSummary(for: log) {
                Text(context)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            if let triggersCoping = triggersCopingSummary(for: log) {
                Text(triggersCoping)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            if let mood = moodScaleSummary(for: log) {
                Text(mood)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            if !log.note.isEmpty {
                JournalText(text: log.note)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.cardAXLabel(for: log))
    }

    nonisolated static func cardAXLabel(for log: FeelingLog) -> String {
        let date = log.createdAt.formatted(date: .abbreviated, time: .shortened)
        let path = log.pathTitle.replacingOccurrences(of: " > ", with: ", ")
        var parts = ["\(date): \(path)"]
        if let intensity = log.intensity {
            parts.append("intensity \(intensity) of 5")
        }
        if !log.note.isEmpty {
            parts.append("with a note")
        }
        return parts.joined(separator: ", ")
    }

    private var shareMenu: some View {
        let entryMarkdown = ExportService.markdown(log: log)
        let shareTitle = "Open Feelings — \(log.createdAt.formatted(date: .abbreviated, time: .shortened))"

        return HStack {
            Spacer()
            Menu {
                ShareLink(
                    item: entryMarkdown,
                    subject: Text(shareTitle),
                    message: Text(shareTitle)
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                if JournalShareService.dayOneInstalled,
                   let url = JournalShareService.dayOneURL(forMarkdown: entryMarkdown) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Send to Day One", systemImage: "book.closed")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel("Share or send entry")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private func bodySummary(for log: FeelingLog) -> String? {
        let regions = log.bodyRegions.map(\.displayName.localizedLowercase)
        let sensations = log.bodySensations.map(\.displayName.localizedLowercase)
        guard !regions.isEmpty || !sensations.isEmpty else { return nil }
        let regionPart   = regions.isEmpty   ? "" : regions.joined(separator: ", ")
        let sensationPart = sensations.isEmpty ? "" : sensations.joined(separator: ", ")
        if !regionPart.isEmpty && !sensationPart.isEmpty {
            return "\(regionPart) · \(sensationPart)"
        }
        return regionPart.isEmpty ? "· \(sensationPart)" : regionPart
    }

    private func contextSummary(for log: FeelingLog) -> String? {
        let places = log.contextPlaces.map(\.displayName.localizedLowercase)
        let people = log.contextPeople.map(\.displayName.localizedLowercase)
        guard !places.isEmpty || !people.isEmpty else { return nil }
        let placePart  = places.isEmpty ? "" : places.joined(separator: ", ")
        let peoplePart = people.isEmpty ? "" : people.joined(separator: ", ")
        if !placePart.isEmpty && !peoplePart.isEmpty {
            return "\(placePart) · \(peoplePart)"
        }
        return placePart.isEmpty ? peoplePart : placePart
    }

    private func triggersCopingSummary(for log: FeelingLog) -> String? {
        let triggers = log.triggers.map(\.displayName.localizedLowercase)
        let coping   = log.coping.map(\.displayName.localizedLowercase)
        guard !triggers.isEmpty || !coping.isEmpty else { return nil }
        let triggerPart = triggers.isEmpty ? "" : triggers.joined(separator: ", ")
        let copingPart  = coping.isEmpty   ? "" : coping.joined(separator: ", ")
        if !triggerPart.isEmpty && !copingPart.isEmpty {
            return "\(triggerPart) → \(copingPart)"
        }
        return triggerPart.isEmpty ? copingPart : triggerPart
    }

    private func moodScaleSummary(for log: FeelingLog) -> String? {
        let energy  = log.moodEnergy.map(MoodScale.energyBand)
        let valence = log.moodValence.map(MoodScale.valenceBand)
        guard energy != nil || valence != nil else { return nil }
        let parts = [energy, valence].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    private func intensityDots(intensity: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= intensity
                          ? AnyShapeStyle(Color.OF.accent)
                          : AnyShapeStyle(Color.OF.divider))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
