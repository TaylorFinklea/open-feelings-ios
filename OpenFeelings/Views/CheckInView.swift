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
            VStack(alignment: .leading, spacing: 20) {
                Picker("Input mode", selection: modeBinding) {
                    ForEach(CheckInMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

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
            .padding()
        }
        .background(checkInBackground)
        .navigationTitle("Check In")
        .safeAreaInset(edge: .bottom) {
            if let savedMessage {
                Text(savedMessage)
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var mode: CheckInMode {
        get { CheckInMode(rawValue: modeRawValue) ?? .wizard }
        nonmutating set { modeRawValue = newValue.rawValue }
    }

    private var modeBinding: Binding<CheckInMode> {
        Binding(
            get: { mode },
            set: { modeRawValue = $0.rawValue }
        )
    }

    @ViewBuilder
    private var checkInBackground: some View {
        let accent = Color(hex: selection?.colorHex ?? "F4D03F")

        ZStack {
            if colorScheme == .dark {
                Color(red: 0.075, green: 0.067, blue: 0.056)
            } else {
                Color(red: 1.0, green: 0.984, blue: 0.945)
            }

            accent.opacity(colorScheme == .dark ? 0.08 : 0.12)
        }
        .ignoresSafeArea()
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
