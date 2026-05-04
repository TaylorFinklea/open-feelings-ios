import SwiftData
import SwiftUI

struct IntentionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Intention.date, order: .reverse) private var intentions: [Intention]
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]

    @State private var todayDraft: String = ""
    @State private var draftLoaded = false

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private var todaysIntention: Intention? {
        intentions.first { Calendar.current.isDate($0.date, inSameDayAs: startOfToday) }
    }

    private var pastIntentions: [Intention] {
        intentions.filter { !Calendar.current.isDate($0.date, inSameDayAs: startOfToday) }
    }

    private var hasUnsavedChanges: Bool {
        let saved = todaysIntention?.text ?? ""
        return todayDraft.trimmingCharacters(in: .whitespacesAndNewlines)
             != saved.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                heroHeader
                if intentions.isEmpty && logs.isEmpty {
                    emptyHero
                } else {
                    todayEditor
                    if !pastIntentions.isEmpty {
                        lookBackSection
                    }
                }
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadDraftIfNeeded() }
        .onChange(of: todaysIntention?.text) { _, _ in loadDraftIfNeeded() }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text("Today")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text("Intention")
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.lg)
    }

    // MARK: - Today editor

    private var todayEditor: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("What would you like to feel or remember today?")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                TextField("Pause when I feel rushed.", text: $todayDraft, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.OF.body)
                    .padding(CGFloat.OF.md)
                    .background(Color.OF.surface,
                                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                            .stroke(Color.OF.divider, lineWidth: 1)
                    }
                HStack {
                    Text(savedStatus)
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                    Spacer()
                    OFButton(hasUnsavedChanges ? "Save" : "Saved",
                             style: hasUnsavedChanges ? .primary : .secondary,
                             action: saveTodayIntention)
                        .frame(maxWidth: 120)
                        .disabled(!hasUnsavedChanges)
                        .opacity(hasUnsavedChanges ? 1 : 0.5)
                }
            }
        }
    }

    private var savedStatus: String {
        if todaysIntention == nil && todayDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Not yet set"
        }
        if hasUnsavedChanges {
            return "Unsaved changes"
        }
        return "Saved"
    }

    private func loadDraftIfNeeded() {
        // Load on first appear, or if the persisted text changes externally.
        let saved = todaysIntention?.text ?? ""
        if !draftLoaded {
            todayDraft = saved
            draftLoaded = true
        } else if todayDraft.isEmpty && !saved.isEmpty {
            // External update with an empty local draft — adopt it.
            todayDraft = saved
        }
    }

    private func saveTodayIntention() {
        let trimmed = todayDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = todaysIntention {
            existing.text = trimmed
        } else if !trimmed.isEmpty {
            let new = Intention(date: Date(), text: trimmed)
            modelContext.insert(new)
        }
        try? modelContext.save()
    }

    // MARK: - Look-back

    private var lookBackSection: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "Look back")
            ForEach(pastIntentions) { intention in
                OFCard { lookBackRow(intention) }
            }
        }
    }

    @ViewBuilder
    private func lookBackRow(_ intention: Intention) -> some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text(intention.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text(intention.text)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
            if let cores = IntentionDayFelt.topCoreNames(in: intention.date, logs: logs) {
                Text("felt: \(cores.joined(separator: ", "))")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    // MARK: - Empty hero (no intentions, no logs)

    private var emptyHero: some View {
        OFEmptyState(
            glyph: "leaf",
            title: "Set today's intention.",
            bodyText: "Choose what you'd like to feel or remember. We'll show you how the day lands."
        )
    }
}

#Preview {
    NavigationStack { IntentionsView() }
        .modelContainer(for: [FeelingLog.self, Intention.self], inMemory: true)
}
