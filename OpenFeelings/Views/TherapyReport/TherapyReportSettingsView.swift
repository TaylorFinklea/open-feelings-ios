import SwiftData
import SwiftUI
import UIKit

/// Settings entry for the therapy-bridge PDF export. Lets the user choose a
/// time window and a detail level, then generates a clinically-filable PDF
/// and hands it to the iOS share sheet.
struct TherapyReportSettingsView: View {
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]
    @Query(sort: \Intention.date, order: .reverse) private var intentions: [Intention]

    @State private var window: TherapyReportData.Window = .last7Days
    @State private var detailLevel: TherapyReportData.DetailLevel = .patternsAndNotable
    @State private var isGenerating = false
    @State private var shareItem: ShareItem?
    @State private var generationError: String?

    var body: some View {
        Form {
            Section("Window") {
                Picker("Window", selection: $window) {
                    ForEach(TherapyReportData.Window.allCases) { w in
                        Text(w.displayName).tag(w)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Detail level") {
                Picker("Detail level", selection: $detailLevel) {
                    ForEach(TherapyReportData.DetailLevel.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Text(detailLevel.helperText)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            Section {
                Button {
                    generate()
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "doc.richtext")
                        }
                        Text(isGenerating ? "Generating…" : "Generate PDF")
                    }
                }
                .disabled(isGenerating)
            } footer: {
                Text("The PDF stays on your device until you tap share. Nothing is uploaded.")
                    .font(.OF.caption)
            }
        }
        .navigationTitle("Period summary")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url])
        }
        .alert("Couldn't generate PDF", isPresented: Binding(
            get: { generationError != nil },
            set: { if !$0 { generationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(generationError ?? "")
        }
    }

    private func generate() {
        isGenerating = true
        let report = TherapyReportData.build(window: window,
                                             detailLevel: detailLevel,
                                             logs: logs,
                                             intentions: intentions)
        do {
            let url = try TherapyReportPDFService.writePDF(report)
            shareItem = ShareItem(url: url)
        } catch {
            generationError = error.localizedDescription
        }
        isGenerating = false
    }
}

