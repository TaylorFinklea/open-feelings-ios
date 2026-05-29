import SwiftData
import SwiftUI

/// Full edit of a saved check-in. A slim sibling of `CheckInView`: it
/// reuses the same step views, `StepNav`, and `CheckInFlowEngine`, but
/// pre-fills the draft from an existing `FeelingLog` and, on the final
/// step, writes the draft back via `apply(to:)` instead of inserting a
/// new log. No body-nudge, no learning suggestions, no save ribbon, no
/// tab navigation, no HealthKit re-sync — those belong to new-entry only.
///
/// `createdAt`, `id`, `healthSyncStatus`, and `captureSource` are
/// preserved: editing changes *what* was recorded, not *when* or *where*.
struct CheckInEditView: View {
    let log: FeelingLog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("checkInBodyFirst") private var bodyFirst = true
    @AppStorage("checkInPromotedSteps") private var promotedRaw = "strength"

    @State private var draft: CheckInDraft
    @State private var stepIndex = 0

    init(log: FeelingLog) {
        self.log = log
        _draft = State(initialValue: CheckInDraft.from(log: log))
    }

    private var promotedSteps: Set<CheckInStepKind> {
        Set(CheckInStepKind.parseList(promotedRaw))
    }

    private var stepList: [CheckInStepKind] {
        CheckInFlowEngine.steps(bodyFirst: bodyFirst, promotedSteps: promotedSteps)
    }

    private var currentStep: CheckInStepKind {
        stepList[min(stepIndex, stepList.count - 1)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                editingHeader
                StepHeader(
                    stepIndex: stepIndex,
                    totalSteps: stepList.count,
                    title: title(for: currentStep),
                    subtitle: subtitle(for: currentStep),
                    selectedFeeling: shouldShowBadge ? draft.selection : nil,
                    intensity: draft.includeIntensity ? Int(draft.intensity.rounded()) : nil
                )
                stepContent
                StepNav(
                    canGoBack: stepIndex > 0,
                    canSkip: !isFirstStep && currentStep != .feeling,
                    canAdvance: canAdvance,
                    isFinalStep: stepIndex == stepList.count - 1,
                    onBack: goBack,
                    onSkip: goNext,
                    onAdvance: advance
                )
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
            .animation(reduceMotion ? nil : .OF.gentle, value: stepIndex)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("Edit check-in")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("checkin-edit.view")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var editingHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Editing \(log.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            if log.captureSource == "watch" {
                Label("From Apple Watch", systemImage: "applewatch")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    // MARK: - Step content dispatch (no nudge / no learning vs CheckInView)

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .body:
            BodyStep(draft: $draft)
        case .feeling:
            FeelingStep(
                draft: $draft,
                suggestedCoreIDs: [],
                nudge: nil,
                onSaveOverride: { _, _ in },
                onDismissNudge: {}
            )
        case .strength:
            StrengthStep(draft: $draft)
        case .sensations:
            SensationsStep(draft: $draft)
        case .context:
            ContextStep(draft: $draft)
        case .triggers:
            TriggersStep(draft: $draft)
        case .coping:
            CopingStep(draft: $draft)
        case .mood:
            MoodStep(draft: $draft)
        case .reflect:
            ReflectStep(draft: $draft, promotedSteps: promotedSteps)
        }
    }

    // MARK: - Titles (mirror CheckInView)

    private func title(for kind: CheckInStepKind) -> String {
        switch kind {
        case .body:       "Where do you feel it?"
        case .feeling:    "How are you feeling?"
        case .strength:   "How strong?"
        case .sensations: "How does it feel?"
        case .context:    "What was happening?"
        case .triggers:   "What brought it on?"
        case .coping:     "What helped?"
        case .mood:       "Mood scale"
        case .reflect:    "Anything to remember?"
        }
    }

    private func subtitle(for kind: CheckInStepKind) -> String {
        switch kind {
        case .body:       "Optional."
        case .feeling:    "Pick the feeling that fits."
        case .strength:   "Optional."
        case .sensations: "Optional."
        case .context:    "Optional."
        case .triggers:   "Optional."
        case .coping:     "Optional."
        case .mood:       "Optional."
        case .reflect:    "All optional."
        }
    }

    private var shouldShowBadge: Bool {
        guard let feelingIdx = stepList.firstIndex(of: .feeling) else { return false }
        return stepIndex > feelingIdx && draft.selection?.isComplete == true
    }

    private var isFirstStep: Bool { stepIndex == 0 }

    // MARK: - Advancement

    private var canAdvance: Bool {
        if currentStep == .feeling { return draft.selection?.isComplete == true }
        if stepIndex == stepList.count - 1 { return draft.canSave }
        return true
    }

    private func advance() {
        if stepIndex == stepList.count - 1 {
            save()
        } else {
            withAnimation(reduceMotion ? nil : .OF.gentle) {
                stepIndex += 1
            }
        }
    }

    private func goBack() {
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            stepIndex = max(0, stepIndex - 1)
        }
    }

    private func goNext() {
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            stepIndex = min(stepList.count - 1, stepIndex + 1)
        }
    }

    private func save() {
        guard draft.canSave else { return }
        draft.apply(to: log)
        try? modelContext.save()
        dismiss()
    }
}
