import SwiftData
import SwiftUI

private enum CheckInMode: String, CaseIterable, Identifiable {
    case wizard = "Wizard"
    case wheel = "Wheel"

    var id: String { rawValue }
}

/// Position of a step within the wizard. Content for each position depends
/// on the user's `bodyFirst` preference — in body-first mode, position 0 is
/// the somatic / context / triggers chips and the emotion picker is at
/// position 1; in feeling-first mode the emotion picker is at position 0.
/// Position 2 is always the reflect / journal step.
private enum CheckInStep: Int, CaseIterable, Identifiable {
    case first = 0
    case second = 1
    case reflect = 2

    var id: Int { rawValue }
}

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthService.self) private var healthService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("healthEnabled") private var healthEnabled = false
    @AppStorage("checkInMode") private var modeRawValue = CheckInMode.wizard.rawValue
    @AppStorage("checkInBodyFirst") private var bodyFirst = true

    @State private var step: CheckInStep = .first
    @State private var selection: EmotionSelection?
    @State private var note = ""
    @State private var includeIntensity = false
    @State private var intensity = 3.0
    @State private var includeMoodScale = false
    @State private var moodEnergy: Double = 0
    @State private var moodValence: Double = 0
    @State private var bodyRegions: Set<BodyRegion> = []
    @State private var bodySensations: Set<BodySensation> = []
    @State private var contextPlaces: Set<ContextPlace> = []
    @State private var contextPeople: Set<ContextPeople> = []
    @State private var triggers: Set<Trigger> = []
    @State private var coping: Set<Coping> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                stepHeader
                stepContent
                stepNav
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
            .animation(reduceMotion ? nil : .OF.gentle, value: step)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header (progress + title + selected-feeling badge)

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            progressBar
            Text("Step \(step.rawValue + 1) of \(CheckInStep.allCases.count)")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
                .padding(.top, .OF.xs)
            Text(currentTitle)
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
            Text(currentSubtitle)
                .font(.OF.body)
                .foregroundStyle(Color.OF.textMuted)
            if shouldShowFeelingBadge, let selection {
                feelingBadge(selection)
            }
        }
        .padding(.top, .OF.lg)
    }

    private var currentTitle: String {
        switch (step, bodyFirst) {
        case (.first,   true):  "Pause and notice."
        case (.second,  true):  "What's the feeling?"
        case (.first,   false): "How are you feeling?"
        case (.second,  false): "Anything else?"
        case (.reflect, _):     "Anything to remember?"
        }
    }

    private var currentSubtitle: String {
        switch (step, bodyFirst) {
        case (.first,   true):  "Body, context, what brought it on — all optional."
        case (.second,  true):  "Pick the feeling, plus optional intensity and mood."
        case (.first,   false): "Pick the feeling that fits."
        case (.second,  false): "Intensity, mood, body, context — all optional."
        case (.reflect, _):     "A note for your future self — also optional."
        }
    }

    /// The selected-feeling badge shows on every step *after* the emotion is
    /// picked, so users have context on later steps. In body-first mode that's
    /// step 2 onward; in feeling-first mode that's step 1 onward.
    private var shouldShowFeelingBadge: Bool {
        switch (step, bodyFirst) {
        case (.first, true):    false   // emotion not chosen yet
        case (.first, false):   false   // user is on the picker itself
        default:                true
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(CheckInStep.allCases) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue
                          ? AnyShapeStyle(Color.OF.accent)
                          : AnyShapeStyle(Color.OF.divider))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func feelingBadge(_ s: EmotionSelection) -> some View {
        HStack(spacing: .OF.sm) {
            Circle()
                .fill(Color.OF.core(s.core.id))
                .frame(width: 12, height: 12)
            Text(s.title)
                .font(.OF.bodyEmphasis)
                .foregroundStyle(Color.OF.text)
            if !s.pathTitle.isEmpty {
                Text("·")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Text(s.pathTitle)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, .OF.xs)
        .padding(.horizontal, .OF.md)
        .background(Color.OF.surface, in: Capsule())
        .overlay(Capsule().stroke(Color.OF.divider, lineWidth: 1))
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch (step, bodyFirst) {
        case (.first,  true):  bodyContextTriggersStep
        case (.second, true):  feelingPlusIntensityStep
        case (.first,  false): feelingOnlyStep
        case (.second, false): allOptionalDetailsStep
        case (.reflect, _):    reflectStep
        }
    }

    /// Body-first mode, position 0: somatic + context + triggers.
    @ViewBuilder
    private var bodyContextTriggersStep: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            BodyChipsCard(bodyRegions: $bodyRegions, bodySensations: $bodySensations)
            ContextChipsCard(contextPlaces: $contextPlaces, contextPeople: $contextPeople)
            TriggersCopingChipsCard(triggers: $triggers, coping: $coping)
        }
    }

    /// Body-first mode, position 1: emotion picker + intensity + mood.
    @ViewBuilder
    private var feelingPlusIntensityStep: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            modeSegmented
            Group {
                switch mode {
                case .wizard: WizardCheckInView(selection: $selection)
                case .wheel:  WheelCheckInView(selection: $selection)
                }
            }
            if let selection {
                EmotionDefinitionCard(
                    definition: selection.definition,
                    accent: Color.OF.accent.color(for: colorScheme),
                    showsDisclaimer: true
                )
            }
            intensityCard
            moodScaleCard
        }
    }

    /// Feeling-first mode, position 0: emotion picker only.
    @ViewBuilder
    private var feelingOnlyStep: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            modeSegmented
            Group {
                switch mode {
                case .wizard: WizardCheckInView(selection: $selection)
                case .wheel:  WheelCheckInView(selection: $selection)
                }
            }
            if let selection {
                EmotionDefinitionCard(
                    definition: selection.definition,
                    accent: Color.OF.accent.color(for: colorScheme),
                    showsDisclaimer: true
                )
            }
        }
    }

    /// Feeling-first mode, position 1: every optional dimension.
    @ViewBuilder
    private var allOptionalDetailsStep: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            intensityCard
            moodScaleCard
            BodyChipsCard(bodyRegions: $bodyRegions, bodySensations: $bodySensations)
            ContextChipsCard(contextPlaces: $contextPlaces, contextPeople: $contextPeople)
            TriggersCopingChipsCard(triggers: $triggers, coping: $coping)
        }
    }

    @ViewBuilder
    private var reflectStep: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            journalCard
        }
    }

    // MARK: - Mode toggle (Wizard / Wheel) on Step 1

    private var modeSegmented: some View {
        HStack(spacing: 0) {
            ForEach(CheckInMode.allCases) { m in
                Button {
                    withAnimation(.OF.quick) { modeRawValue = m.rawValue }
                } label: {
                    Text(m.rawValue)
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(mode == m ? Color.OF.text : Color.OF.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            Group {
                                if mode == m {
                                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip, style: .continuous)
                                        .fill(Color.OF.surface)
                                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.OF.accentSoft.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip + 4, style: .continuous))
    }

    private var mode: CheckInMode {
        get { CheckInMode(rawValue: modeRawValue) ?? .wizard }
        nonmutating set { modeRawValue = newValue.rawValue }
    }

    // MARK: - Detail cards (intensity, mood)

    private var intensityCard: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Toggle(isOn: $includeIntensity) {
                Text("Intensity").font(.OF.bodyEmphasis)
            }
            if includeIntensity {
                HStack(spacing: .OF.sm) {
                    intensityDots
                    Slider(value: $intensity, in: 1...5, step: 1)
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private var intensityDots: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= Int(intensity.rounded())
                          ? AnyShapeStyle(Color.OF.accent)
                          : AnyShapeStyle(Color.OF.divider))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var moodScaleCard: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Toggle(isOn: $includeMoodScale) {
                Text("Mood scale").font(.OF.bodyEmphasis)
            }
            if includeMoodScale {
                VStack(alignment: .leading, spacing: .OF.md) {
                    moodSlider(
                        title: "Energy",
                        leftLabel: "calm",
                        rightLabel: "activated",
                        value: $moodEnergy
                    )
                    moodSlider(
                        title: "Valence",
                        leftLabel: "unpleasant",
                        rightLabel: "pleasant",
                        value: $moodValence
                    )
                }
                .padding(.top, .OF.xs)
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func moodSlider(
        title: String,
        leftLabel: String,
        rightLabel: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            HStack {
                Text(title).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text(currentMoodLabel(title: title, value: value.wrappedValue))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.text)
            }
            Slider(value: value, in: -1...1, step: 0.05)
                .tint(Color.OF.accent.color(for: colorScheme))
            HStack {
                Text(leftLabel).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text(rightLabel).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    private func currentMoodLabel(title: String, value: Double) -> String {
        title == "Energy" ? MoodScale.energyBand(value) : MoodScale.valenceBand(value)
    }

    // MARK: - Journal card (Step 3)

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Journal".uppercased())
                .font(.OF.caption).tracking(1.0)
                .foregroundStyle(Color.OF.textMuted)
            TextEditor(text: $note)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }
                .accessibilityLabel("Journal entry")
            Text("Anything you want to remember about this moment.")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
        }
    }

    // MARK: - Step navigation

    private var stepNav: some View {
        HStack(spacing: .OF.md) {
            if step != .first {
                OFButton("Back", style: .ghost) {
                    withAnimation(reduceMotion ? nil : .OF.gentle) {
                        if let prev = CheckInStep(rawValue: step.rawValue - 1) {
                            step = prev
                        }
                    }
                }
            }
            primaryStepButton
        }
    }

    @ViewBuilder
    private var primaryStepButton: some View {
        switch step {
        case .first:
            OFButton("Continue", style: .primary) {
                withAnimation(reduceMotion ? nil : .OF.gentle) { step = .second }
            }
            .opacity(canAdvanceFromFirst ? 1 : 0.4)
            .disabled(!canAdvanceFromFirst)
        case .second:
            OFButton("Continue", style: .primary) {
                withAnimation(reduceMotion ? nil : .OF.gentle) { step = .reflect }
            }
            .opacity(canAdvanceFromSecond ? 1 : 0.4)
            .disabled(!canAdvanceFromSecond)
        case .reflect:
            OFButton("Save check-in", style: .primary, action: save)
                .opacity(canSave ? 1 : 0.4)
                .disabled(!canSave)
        }
    }

    /// Step 1 → 2: in body-first mode the first step is all optional, so
    /// always advanceable. In feeling-first mode the user must pick a
    /// complete emotion before continuing.
    private var canAdvanceFromFirst: Bool {
        bodyFirst ? true : (selection?.isComplete == true)
    }

    /// Step 2 → 3: in body-first mode this is where the emotion picker
    /// lives, so we gate on selection. In feeling-first mode step 2 is
    /// all-optional details.
    private var canAdvanceFromSecond: Bool {
        bodyFirst ? (selection?.isComplete == true) : true
    }

    private var canSave: Bool {
        selection?.isComplete == true
    }

    // MARK: - Save / reset

    private func save() {
        guard let selection, selection.isComplete else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = FeelingLog(
            selection: selection,
            intensity: includeIntensity ? Int(intensity.rounded()) : nil,
            note: trimmedNote,
            healthSyncStatus: healthEnabled ? .pending : .notRequested,
            bodyRegions: BodyRegion.allCases.filter { bodyRegions.contains($0) },
            bodySensations: BodySensation.allCases.filter { bodySensations.contains($0) },
            contextPlaces: ContextPlace.allCases.filter { contextPlaces.contains($0) },
            contextPeople: ContextPeople.allCases.filter { contextPeople.contains($0) },
            triggers: Trigger.allCases.filter { triggers.contains($0) },
            coping: Coping.allCases.filter { coping.contains($0) },
            moodEnergy: includeMoodScale ? moodEnergy : nil,
            moodValence: includeMoodScale ? moodValence : nil
        )
        modelContext.insert(log)
        try? modelContext.save()
        resetDraft()

        navigation.ribbonAfterSave()
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            navigation.select(.today)
        }

        Task { @MainActor in
            log.healthSyncStatus = await healthService.save(log: log, isEnabled: healthEnabled)
            try? modelContext.save()
        }
    }

    private func resetDraft() {
        step = .first
        selection = nil
        note = ""
        includeIntensity = false
        intensity = 3
        includeMoodScale = false
        moodEnergy = 0
        moodValence = 0
        bodyRegions = []
        bodySensations = []
        contextPlaces = []
        contextPeople = []
        triggers = []
        coping = []
    }
}

// MARK: - Reusable chip cards (used by Step 2)

/// Body chip card. Renders region chips, then sensation chips progressively
/// (only after a region is selected).
private struct BodyChipsCard: View {
    @Binding var bodyRegions: Set<BodyRegion>
    @Binding var bodySensations: Set<BodySensation>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Body").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
            Text("Where do you feel it?")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            regionChips
            if !bodyRegions.isEmpty {
                Divider().background(Color.OF.divider).padding(.vertical, CGFloat.OF.xs)
                Text("How does it feel?")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                sensationChips
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private var regionChips: some View {
        WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
            ForEach(BodyRegion.allCases) { region in
                OFChip(label: region.displayName, isOn: regionBinding(for: region))
            }
        }
    }

    private var sensationChips: some View {
        WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
            ForEach(BodySensation.allCases) { sensation in
                OFChip(label: sensation.displayName, isOn: sensationBinding(for: sensation))
            }
        }
    }

    private func regionBinding(for region: BodyRegion) -> Binding<Bool> {
        Binding(
            get: { bodyRegions.contains(region) },
            set: { isOn in
                if isOn { bodyRegions.insert(region) } else { bodyRegions.remove(region) }
            }
        )
    }

    private func sensationBinding(for sensation: BodySensation) -> Binding<Bool> {
        Binding(
            get: { bodySensations.contains(sensation) },
            set: { isOn in
                if isOn { bodySensations.insert(sensation) } else { bodySensations.remove(sensation) }
            }
        )
    }
}

/// Context chip card. Renders place chips and people chips as two distinct
/// sub-sections — both visible from the start since they're independent axes.
private struct ContextChipsCard: View {
    @Binding var contextPlaces: Set<ContextPlace>
    @Binding var contextPeople: Set<ContextPeople>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Context").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
            Text("Where were you?")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            placeChips
            Divider().background(Color.OF.divider).padding(.vertical, CGFloat.OF.xs)
            Text("Who were you with?")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            peopleChips
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private var placeChips: some View {
        WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
            ForEach(ContextPlace.allCases) { place in
                OFChip(label: place.displayName, isOn: placeBinding(for: place))
            }
        }
    }

    private var peopleChips: some View {
        WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
            ForEach(ContextPeople.allCases) { people in
                OFChip(label: people.displayName, isOn: peopleBinding(for: people))
            }
        }
    }

    private func placeBinding(for place: ContextPlace) -> Binding<Bool> {
        Binding(
            get: { contextPlaces.contains(place) },
            set: { isOn in
                if isOn { contextPlaces.insert(place) } else { contextPlaces.remove(place) }
            }
        )
    }

    private func peopleBinding(for people: ContextPeople) -> Binding<Bool> {
        Binding(
            get: { contextPeople.contains(people) },
            set: { isOn in
                if isOn { contextPeople.insert(people) } else { contextPeople.remove(people) }
            }
        )
    }
}

/// Triggers + coping chip card. Two distinct sub-sections — they're
/// independent: a user can record what happened, what they did, neither, or
/// both.
private struct TriggersCopingChipsCard: View {
    @Binding var triggers: Set<Trigger>
    @Binding var coping: Set<Coping>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Triggers & coping").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
            Text("What brought it on?")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            triggerChips
            Divider().background(Color.OF.divider).padding(.vertical, CGFloat.OF.xs)
            Text("What helped?")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            copingChips
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private var triggerChips: some View {
        WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
            ForEach(Trigger.allCases) { t in
                OFChip(label: t.displayName, isOn: triggerBinding(for: t))
            }
        }
    }

    private var copingChips: some View {
        WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
            ForEach(Coping.allCases) { c in
                OFChip(label: c.displayName, isOn: copingBinding(for: c))
            }
        }
    }

    private func triggerBinding(for t: Trigger) -> Binding<Bool> {
        Binding(
            get: { triggers.contains(t) },
            set: { isOn in
                if isOn { triggers.insert(t) } else { triggers.remove(t) }
            }
        )
    }

    private func copingBinding(for c: Coping) -> Binding<Bool> {
        Binding(
            get: { coping.contains(c) },
            set: { isOn in
                if isOn { coping.insert(c) } else { coping.remove(c) }
            }
        )
    }
}
