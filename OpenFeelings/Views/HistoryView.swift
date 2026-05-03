import SwiftData
import SwiftUI
import UIKit

struct HistoryView: View {
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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
                title: "No check-ins yet",
                bodyText: "Check-ins you save will show up here."
            )
        } else {
            ScrollView {
                VStack(spacing: .OF.md) {
                    ForEach(logs) { log in
                        OFCard { LogCard(log: log) }
                    }
                }
                .padding(.horizontal, CGFloat.OF.lg)
                .padding(.bottom, CGFloat.OF.xxxl)
                .padding(.top, CGFloat.OF.lg)
            }
        }
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
}

private struct LogCard: View {
    let log: FeelingLog

    var body: some View {
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
                Text("\u{201C}\(log.note)\u{201D}")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .padding(.top, 2)
            }
        }
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

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
