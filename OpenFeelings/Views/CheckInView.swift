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
    @State private var bodyRegions: Set<BodyRegion> = []
    @State private var bodySensations: Set<BodySensation> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                heroHeader
                if bodyFirst {
                    BodyChipsCard(
                        bodyRegions: $bodyRegions,
                        bodySensations: $bodySensations
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
                    bodyRegions: $bodyRegions,
                    bodySensations: $bodySensations,
                    showsBodySection: !bodyFirst,
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
            bodySensations: BodySensation.allCases.filter { bodySensations.contains($0) }
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
        bodyRegions = []
        bodySensations = []
    }
}

private struct LogComposerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let selection: EmotionSelection?
    @Binding var note: String
    @Binding var includeIntensity: Bool
    @Binding var intensity: Double
    @Binding var bodyRegions: Set<BodyRegion>
    @Binding var bodySensations: Set<BodySensation>
    /// When false, body chips render above the wheel/wizard (body-first mode)
    /// and this composer skips its inline bodySection.
    let showsBodySection: Bool
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
                if showsBodySection {
                    bodySection
                }
                placeholderRows
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

    private var placeholderRows: some View {
        VStack(spacing: 0) {
            OFSectionHeader(title: "Coming soon")
            placeholderRow(symbol: "location",      title: "Context")
            Divider().background(Color.OF.divider)
            placeholderRow(symbol: "bolt",          title: "Triggers / coping")
            Divider().background(Color.OF.divider)
            placeholderRow(symbol: "waveform.path", title: "Mood scale")
        }
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
        .opacity(0.55)
    }

    private func placeholderRow(symbol: String, title: String) -> some View {
        HStack(spacing: .OF.md) {
            Image(systemName: symbol).foregroundStyle(Color.OF.textMuted).frame(width: 24)
            Text(title).font(.OF.body).foregroundStyle(Color.OF.textMuted)
            Spacer()
        }
        .padding(.horizontal, CGFloat.OF.lg)
        .padding(.vertical, CGFloat.OF.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint("Coming soon, currently unavailable")
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
