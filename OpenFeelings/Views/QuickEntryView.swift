// OpenFeelings/Views/QuickEntryView.swift
import SwiftData
import SwiftUI

/// Natural-language quick entry. Type or dictate one sentence → parse → a
/// compact Review of the three core fields → save. Seeded mode (from the Siri
/// hand-off) parses an incoming note and opens straight into Review.
struct QuickEntryView: View {
    let seededNote: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthService.self) private var healthService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    @AppStorage("healthEnabled") private var healthEnabled = false

    @State private var phase: Phase = .capture
    @State private var text = ""
    @State private var draft = CheckInDraft()

    private enum Phase { case capture, review }

    init(seededNote: String? = nil) {
        self.seededNote = seededNote
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                switch phase {
                case .capture: captureView
                case .review: reviewView
                }
            }
            .padding(.horizontal, .OF.lg)
            .padding(.vertical, .OF.lg)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("Quick entry")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("quickentry.view")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            if let seededNote { await runParse(on: seededNote) }
        }
    }

    // MARK: Capture

    private var captureView: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            Text("Say how you feel")
                .ofTitle().foregroundStyle(Color.OF.text)
            Text("Type or tap the mic — e.g. \u{201C}anxious about the demo, 4/5\u{201D}.")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            TextEditor(text: $text)
                .font(.OF.body).foregroundStyle(Color.OF.text)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card).stroke(Color.OF.divider, lineWidth: 1)
                }
                .accessibilityIdentifier("quickentry.field")
            Button {
                Task { await runParse(on: text) }
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("quickentry.continue")
        }
    }

    // MARK: Review

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: .OF.xl) {
            Text("Does this look right?")
                .ofTitle().foregroundStyle(Color.OF.text)
            FeelingStep(draft: $draft, suggestedCoreIDs: [], nudge: nil, onSaveOverride: { _, _ in }, onDismissNudge: {})
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("How strong?").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                IntensityDots(draft: $draft)
            }
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Note").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                TextEditor(text: $draft.note)
                    .font(.OF.body).foregroundStyle(Color.OF.text)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(CGFloat.OF.md)
                    .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                    .accessibilityLabel("Note")
            }
            Button {
                save()
            } label: {
                Text("Save").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .accessibilityIdentifier("quickentry.save")
        }
    }

    // MARK: Actions

    private func runParse(on input: String) async {
        let parsed = await FeelingParserProvider.current().parse(input)
        draft = parsed.toDraft()
        phase = .review
    }

    private func save() {
        guard let log = FeelingLogService.persist(
            draft: draft, captureSource: "quickentry",
            into: modelContext, healthEnabled: healthEnabled
        ) else { return }
        navigation.ribbonAfterSave()
        navigation.select(.today)
        Task { @MainActor in
            await FeelingLogService.syncHealth(log, healthService: healthService, healthEnabled: healthEnabled, into: modelContext)
        }
        dismiss()
    }
}
