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

            if !log.note.isEmpty {
                Text("\u{201C}\(log.note)\u{201D}")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .padding(.top, 2)
            }
        }
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
