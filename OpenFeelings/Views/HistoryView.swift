import SwiftData
import SwiftUI
import UIKit

struct HistoryView: View {
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView(
                    "No check-ins yet",
                    systemImage: "text.badge.plus",
                    description: Text("Saved feelings will appear here.")
                )
            } else {
                ForEach(logs) { log in
                    FeelingLogRow(log: log)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportCSV()
                    } label: {
                        Label("Export CSV", systemImage: "tablecells")
                    }

                    Button {
                        exportJSON()
                    } label: {
                        Label("Export JSON", systemImage: "curlybraces")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(logs.isEmpty)
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

private struct FeelingLogRow: View {
    let log: FeelingLog

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(log.emotionTitle)
                    .font(.headline)

                Spacer()

                Text(log.createdAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(log.pathTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let intensity = log.intensity {
                    Label("\(intensity)/5", systemImage: "gauge.with.dots.needle.33percent")
                }

                Label(log.healthSyncStatus.label, systemImage: "heart.text.square")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !log.note.isEmpty {
                Text(log.note)
                    .font(.callout)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
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
