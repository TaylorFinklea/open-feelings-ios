import SwiftData
import SwiftUI

/// Entry point for the Check In tab. Orchestrates a step list computed from
/// the user's settings (Body First, promoted steps) and dispatches to per-step
/// views. Holds all draft state in a `CheckInDraft`.
struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthService.self) private var healthService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("healthEnabled") private var healthEnabled = false
    @AppStorage("checkInBodyFirst") private var bodyFirst = true
    @AppStorage("checkInPromotedSteps") private var promotedRaw = "strength"
    @AppStorage("checkInLearnFromHistory") private var learnFromHistory = true

    @Query private var allLogs: [FeelingLog]
    @Query private var bodyMaps: [UserBodyMap]

    @State private var draft = CheckInDraft()
    @State private var stepIndex = 0
    @State private var dismissedNudgeRegions: Set<BodyRegion> = []

    private var promotedSteps: Set<CheckInStepKind> {
        Set(CheckInStepKind.parseList(promotedRaw))
    }

    private var stepList: [CheckInStepKind] {
        CheckInFlowEngine.steps(bodyFirst: bodyFirst, promotedSteps: promotedSteps)
    }

    private var currentStep: CheckInStepKind {
        stepList[min(stepIndex, stepList.count - 1)]
    }

    private var bodyMap: UserBodyMap {
        bodyMaps.first ?? UserBodyMap()
    }

    private var learnedMap: LearnedBodyMap {
        guard learnFromHistory else {
            return LearnedBodyMap(counts: [:], totals: [:], customCounts: [:], customTotals: [:])
        }
        return LearnedBodyMap.compute(from: allLogs)
    }

    private var suggestedCoreIDs: Set<String> {
        BodyEmotionMap.suggestedCores(for: draft.bodyRegions, overrides: bodyMap)
    }

    private var nudgePayload: FeelingStep.NudgePayload? {
        guard let region = draft.bodyRegions.first(where: { $0 != .wholeBody && $0 != .nowhere }),
              !dismissedNudgeRegions.contains(region) else { return nil }
        // Don't nudge when an override already exists.
        if bodyMap.coreIDs(for: region) != nil { return nil }
        guard let secondaryID = learnedMap.dominantSecondary(for: region),
              let total = learnedMap.totals[region],
              let count = learnedMap.counts[region]?[secondaryID] else { return nil }
        // Resolve secondary name.
        let secondaryName = EmotionTaxonomy.cores
            .flatMap { $0.secondaries }
            .first { $0.id == secondaryID }?.name ?? secondaryID
        return FeelingStep.NudgePayload(
            region: region,
            secondaryID: secondaryID,
            secondaryName: secondaryName,
            count: count,
            total: total
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ensureUserBodyMapExists() }
    }

    // MARK: - Step content dispatch

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .body:
            BodyStep(draft: $draft)
        case .feeling:
            FeelingStep(
                draft: $draft,
                suggestedCoreIDs: suggestedCoreIDs,
                nudge: nudgePayload,
                onSaveOverride: saveOverride,
                onDismissNudge: dismissNudge
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

    // MARK: - Titles

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
        case .feeling:    draft.bodyRegions.isEmpty ? "Pick the feeling that fits." : "Suggestions based on your body picks."
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
        // Show badge from feeling-step onward.
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

    // MARK: - Body map override

    private func saveOverride(region: BodyRegion, secondaryID: String) {
        // Translate secondary → its parent core, persist as a single-core
        // override. (Spec uses core-level overrides; learned secondary is
        // promoted by adding its parent core to the override list.)
        guard let core = EmotionTaxonomy.cores.first(where: { core in
            core.secondaries.contains { $0.id == secondaryID }
        }) else { return }
        bodyMap.setOverride(for: region, coreIDs: [core.id])
        try? modelContext.save()
        dismissedNudgeRegions.insert(region)
    }

    private func dismissNudge() {
        if let region = draft.bodyRegions.first(where: { $0 != .wholeBody && $0 != .nowhere }) {
            dismissedNudgeRegions.insert(region)
        }
    }

    private func ensureUserBodyMapExists() {
        if bodyMaps.isEmpty {
            modelContext.insert(UserBodyMap())
            try? modelContext.save()
        }
    }

    // MARK: - Save (preserves the old save() exactly)

    private func save() {
        guard let log = FeelingLogService.persist(
            draft: draft, captureSource: "phone",
            into: modelContext, healthEnabled: healthEnabled
        ) else { return }
        draft.reset()
        stepIndex = 0
        dismissedNudgeRegions.removeAll()

        navigation.ribbonAfterSave()
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            navigation.select(.today)
        }

        Task { @MainActor in
            await FeelingLogService.syncHealth(
                log, healthService: healthService,
                healthEnabled: healthEnabled, into: modelContext
            )
        }
    }
}
