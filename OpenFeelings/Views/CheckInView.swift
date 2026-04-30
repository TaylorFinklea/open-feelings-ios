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
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("healthEnabled") private var healthEnabled = false
    @AppStorage("checkInMode") private var modeRawValue = CheckInMode.wizard.rawValue

    @State private var selection: EmotionSelection?
    @State private var note = ""
    @State private var includeIntensity = false
    @State private var intensity = 3.0
    @State private var savedMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                heroHeader
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
                    save: save
                )
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let savedMessage {
                Text(savedMessage)
                    .font(.OF.bodyEmphasis)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .OF.md)
                    .background(.thinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text("Now")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text("How are you feeling?")
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.lg)
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
        guard let selection, selection.isComplete else {
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = FeelingLog(
            selection: selection,
            intensity: includeIntensity ? Int(intensity.rounded()) : nil,
            note: trimmedNote,
            healthSyncStatus: healthEnabled ? .pending : .notRequested
        )

        modelContext.insert(log)
        try? modelContext.save()

        resetDraft()
        withAnimation {
            savedMessage = "Saved \(log.specificName)"
        }

        Task { @MainActor in
            log.healthSyncStatus = await healthService.save(log: log, isEnabled: healthEnabled)
            try? modelContext.save()

            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                savedMessage = nil
            }
        }
    }

    private func resetDraft() {
        selection = nil
        note = ""
        includeIntensity = false
        intensity = 3
    }
}

private struct LogComposerView: View {
    let selection: EmotionSelection?
    @Binding var note: String
    @Binding var includeIntensity: Bool
    @Binding var intensity: Double

    let save: () -> Void

    var body: some View {
        let accent = Color(hex: selection?.colorHex ?? "8E8E93")

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected feeling")
                    .font(.headline)

                if let selection {
                    Text(selection.pathTitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(selection.isComplete ? .primary : .secondary)

                    EmotionDefinitionCard(
                        definition: selection.definition,
                        accent: accent,
                        showsDisclaimer: false
                    )
                    .padding(.top, 8)

                    if !selection.isComplete {
                        Text("Choose a specific outer feeling to save this check-in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No feeling selected")
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Add intensity", isOn: $includeIntensity)

            if includeIntensity {
                VStack(alignment: .leading) {
                    Text("Intensity \(Int(intensity.rounded()))")
                        .font(.subheadline.weight(.medium))
                    Slider(value: $intensity, in: 1...5, step: 1)
                }
            }

            TextField("Optional note", text: $note, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)

            Button(action: save) {
                Label("Save check-in", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(accent)
            .disabled(selection?.isComplete != true)
        }
        .padding()
        .background(accent.opacity(selection == nil ? 0.08 : 0.16), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent.opacity(selection == nil ? 0.14 : 0.35), lineWidth: 1)
        }
    }
}
