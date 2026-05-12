import SwiftData
import SwiftUI

struct IntentionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Intention.date, order: .reverse) private var intentions: [Intention]
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]

    @State private var todayDraft: String = ""
    @State private var draftLoaded = false
    @State private var expandedIDs: Set<UUID> = []
    @FocusState private var todayFocused: Bool

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
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    todayFocused = false
                } label: {
                    Label("Hide keyboard", systemImage: "keyboard.chevron.compact.down")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .accessibilityLabel("Hide keyboard")
            }
        }
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
                    .focused($todayFocused)
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
        todayFocused = false
    }

    // MARK: - Look-back

    private var lookBackSection: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "Look back")
            ForEach(pastIntentions) { intention in
                PastIntentionRow(
                    intention: intention,
                    topCoreNames: IntentionDayFelt.topCoreNames(in: intention.date, logs: logs),
                    isExpanded: expandedIDs.contains(intention.id),
                    onExpand: { expandedIDs.insert(intention.id) },
                    onCollapse: { expandedIDs.remove(intention.id) },
                    onSave: { newReflection in
                        intention.reflection = newReflection
                        try? modelContext.save()
                    }
                )
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

// MARK: - PastIntentionRow

/// One row in the look-back list. Owns its own draft text so each card's
/// editor is self-contained — collapsing one row doesn't disturb another's
/// pending changes.
private struct PastIntentionRow: View {
    let intention: Intention
    let topCoreNames: [String]?
    let isExpanded: Bool
    let onExpand: () -> Void
    let onCollapse: () -> Void
    let onSave: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: String = ""
    @State private var draftLoaded = false

    private var hasUnsavedChanges: Bool {
        Intention.normalizedReflection(draft) != intention.reflection
    }

    private var statusText: String {
        if intention.reflection.isEmpty
            && Intention.normalizedReflection(draft).isEmpty {
            return "Not yet reflected"
        }
        if hasUnsavedChanges { return "Unsaved changes" }
        return "Saved"
    }

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.xs) {
                Text(intention.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Text(intention.text)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                if let cores = topCoreNames {
                    Text("felt: \(cores.joined(separator: ", "))")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
                if isExpanded {
                    expandedEditor
                } else {
                    collapsedAffordance
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18),
                       value: isExpanded)
        }
        .onAppear { loadDraftIfNeeded() }
        .onChange(of: intention.reflection) { _, newValue in
            // External update — adopt only if the user hasn't typed anything
            // that would otherwise be discarded.
            if !hasUnsavedChanges { draft = newValue }
        }
    }

    @ViewBuilder
    private var collapsedAffordance: some View {
        if intention.reflection.isEmpty {
            OFButton("Reflect on this day", style: .secondary, action: onExpand)
                .frame(maxWidth: 220)
                .padding(.top, .OF.xs)
        } else {
            VStack(alignment: .leading, spacing: .OF.xs) {
                Text("Reflection")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Text(intention.reflection)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                Button(action: onExpand) {
                    Text("Edit")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, .OF.xs)
        }
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            TextField("How did this land?", text: $draft, axis: .vertical)
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
                Text(statusText)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Spacer()
                if hasUnsavedChanges {
                    OFButton("Cancel", style: .secondary) {
                        draft = intention.reflection
                        onCollapse()
                    }
                    .frame(maxWidth: 100)
                }
                OFButton(hasUnsavedChanges ? "Save" : "Done",
                         style: hasUnsavedChanges ? .primary : .secondary) {
                    if hasUnsavedChanges {
                        onSave(Intention.normalizedReflection(draft))
                    }
                    onCollapse()
                }
                .frame(maxWidth: 100)
            }
        }
        .padding(.top, .OF.xs)
    }

    private func loadDraftIfNeeded() {
        if !draftLoaded {
            draft = intention.reflection
            draftLoaded = true
        }
    }
}

#Preview {
    NavigationStack { IntentionsView() }
        .modelContainer(for: [FeelingLog.self, Intention.self], inMemory: true)
}
