import SwiftData
import SwiftUI

private enum CheckInMode: String, CaseIterable, Identifiable {
    case wizard = "Wizard"
    case wheel = "Wheel"

    var id: String { rawValue }
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
                heroHeader
                if bodyFirst {
                    BodyChipsCard(
                        bodyRegions: $bodyRegions,
                        bodySensations: $bodySensations
                    )
                    ContextChipsCard(
                        contextPlaces: $contextPlaces,
                        contextPeople: $contextPeople
                    )
                    TriggersCopingChipsCard(
                        triggers: $triggers,
                        coping: $coping
                    )
                    feelingPrompt
                }
                modeSegmented
                Group {
                    switch mode {
                    case .wizard:
                        WizardCheckInView(selection: $selection)
                    case .wheel:
                        WheelCheckInView(selection: $selection)
                    }
                }
                LogComposerView(
                    selection: selection,
                    note: $note,
                    includeIntensity: $includeIntensity,
                    intensity: $intensity,
                    includeMoodScale: $includeMoodScale,
                    moodEnergy: $moodEnergy,
                    moodValence: $moodValence,
                    bodyRegions: $bodyRegions,
                    bodySensations: $bodySensations,
                    contextPlaces: $contextPlaces,
                    contextPeople: $contextPeople,
                    triggers: $triggers,
                    coping: $coping,
                    showsBodySection: !bodyFirst,
                    showsContextSection: !bodyFirst,
                    showsTriggersCopingSection: !bodyFirst,
                    save: save
                )
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text("Now")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text(bodyFirst ? "Pause and notice." : "How are you feeling?")
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.lg)
    }

    /// In body-first mode, after the body chips, this prompt introduces the
    /// emotion picker below.
    private var feelingPrompt: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text("Then")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text("What feeling matches?")
                .font(.OF.title)
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.sm)
    }

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

        // Show the ribbon on Today and switch tab.
        navigation.ribbonAfterSave()
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            navigation.select(.today)
        }

        // Health write keeps the existing async behavior.
        Task { @MainActor in
            log.healthSyncStatus = await healthService.save(log: log, isEnabled: healthEnabled)
            try? modelContext.save()
        }
    }

    private func resetDraft() {
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

private struct LogComposerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let selection: EmotionSelection?
    @Binding var note: String
    @Binding var includeIntensity: Bool
    @Binding var intensity: Double
    @Binding var includeMoodScale: Bool
    @Binding var moodEnergy: Double
    @Binding var moodValence: Double
    @Binding var bodyRegions: Set<BodyRegion>
    @Binding var bodySensations: Set<BodySensation>
    @Binding var contextPlaces: Set<ContextPlace>
    @Binding var contextPeople: Set<ContextPeople>
    @Binding var triggers: Set<Trigger>
    @Binding var coping: Set<Coping>
    /// When false, body chips render above the wheel/wizard (body-first mode)
    /// and this composer skips its inline bodySection.
    let showsBodySection: Bool
    let showsContextSection: Bool
    let showsTriggersCopingSection: Bool
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            header
            if let selection {
                EmotionDefinitionCard(
                    definition: selection.definition,
                    accent: Color.OF.accent.color(for: colorScheme),
                    showsDisclaimer: true
                )
                intensitySection
                moodScaleSection
                if showsBodySection {
                    bodySection
                }
                if showsContextSection {
                    contextSection
                }
                if showsTriggersCopingSection {
                    triggersCopingSection
                }
                noteField
                saveButton(enabled: selection.isComplete)
            } else {
                Text("Choose a feeling above to continue.")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
        .padding(CGFloat.OF.lg)
        .background(Color.OF.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.sheet, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.sheet, style: .continuous)
                .stroke(Color.OF.divider.opacity(0.7), lineWidth: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selection?.title ?? "No feeling selected")
                .font(.OF.headline)
                .foregroundStyle(Color.OF.text)
            if let selection {
                Text(selection.pathTitle)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    private var intensitySection: some View {
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

    private var bodySection: some View {
        BodyChipsCard(
            bodyRegions: $bodyRegions,
            bodySensations: $bodySensations
        )
    }

    private var contextSection: some View {
        ContextChipsCard(
            contextPlaces: $contextPlaces,
            contextPeople: $contextPeople
        )
    }

    private var triggersCopingSection: some View {
        TriggersCopingChipsCard(
            triggers: $triggers,
            coping: $coping
        )
    }

    private var moodScaleSection: some View {
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
        if title == "Energy" {
            return MoodScale.energyBand(value)
        } else {
            return MoodScale.valenceBand(value)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text("Note (optional)")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            TextField("", text: $note, axis: .vertical)
                .lineLimit(3...8)
                .font(.OF.body)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }
        }
    }

    private func saveButton(enabled: Bool) -> some View {
        OFButton("Save check-in", style: .primary, action: save)
            .opacity(enabled ? 1 : 0.4)
            .disabled(!enabled)
    }
}

/// Reusable body chip card. Renders region chips, then sensation chips
/// progressively (only after a region is selected). Used in two places:
/// inside `LogComposerView` (emotion-first mode) and at the top of
/// `CheckInView` (body-first mode, the therapy-aligned default).
private struct BodyChipsCard: View {
    @Binding var bodyRegions: Set<BodyRegion>
    @Binding var bodySensations: Set<BodySensation>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Body").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
            Text("Where do you feel it? (optional)")
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

/// Reusable context chip card. Renders place chips and people chips as two
/// distinct sub-sections (no progressive disclosure — both visible from the
/// start, since they're independent axes). Used in two places: inside
/// `LogComposerView` (feeling-first mode) and at the top of `CheckInView`
/// after `BodyChipsCard` (body-first mode, the therapy-aligned default).
private struct ContextChipsCard: View {
    @Binding var contextPlaces: Set<ContextPlace>
    @Binding var contextPeople: Set<ContextPeople>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Context").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
            Text("Where were you? (optional)")
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

/// Reusable triggers + coping chip card. Two distinct sub-sections (no
/// progressive disclosure — they're independent: a user can record what
/// happened, what they did, neither, or both). Used in two places: inside
/// `LogComposerView` (feeling-first mode) and at the top of `CheckInView`
/// after `ContextChipsCard` (body-first mode, the therapy-aligned default).
private struct TriggersCopingChipsCard: View {
    @Binding var triggers: Set<Trigger>
    @Binding var coping: Set<Coping>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Triggers & coping").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
            Text("What brought it on? (optional)")
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
