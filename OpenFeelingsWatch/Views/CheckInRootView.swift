import SwiftUI

struct CheckInRootView: View {
    @Environment(WatchSessionClient.self) private var sessionClient
    @State private var step: Step = .core
    @State private var selectedCore: EmotionCore?
    @State private var selectedSecondary: EmotionSecondary?
    @State private var selectedSpecific: EmotionSpecific?
    @State private var intensity: Int = 3
    @State private var bodyRegions: Set<BodyRegion> = []
    @State private var bodySensations: Set<BodySensation> = []
    @State private var note: String = ""
    @State private var didSend: Bool = false

    enum Step: Hashable {
        case core
        case secondary
        case specific
        case intensity
        case body
        case sensations
        case note
        case confirm
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Check In")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .core:
            CoreFeelingPicker { core in
                selectedCore = core
                selectedSecondary = nil
                selectedSpecific = nil
                step = .secondary
            }

        case .secondary:
            if let core = selectedCore {
                SecondaryFeelingPicker(
                    core: core,
                    onStopAtCore: { step = .intensity },
                    onSelect: { secondary in
                        selectedSecondary = secondary
                        selectedSpecific = nil
                        step = .specific
                    }
                )
            }

        case .specific:
            if let secondary = selectedSecondary {
                SpecificFeelingPicker(
                    secondary: secondary,
                    onStopAtSecondary: { step = .intensity },
                    onSelect: { specific in
                        selectedSpecific = specific
                        step = .intensity
                    }
                )
            }

        case .intensity:
            if let core = selectedCore {
                IntensityPicker(
                    core: core,
                    intensity: $intensity,
                    onContinue: { step = .body },
                    onBack: { step = backStepFromIntensity }
                )
            }

        case .body:
            BodyRegionPicker(
                selection: $bodyRegions,
                onContinue: { step = shouldShowSensations ? .sensations : .note }
            )

        case .sensations:
            SensationPicker(
                selection: $bodySensations,
                onContinue: { step = .note }
            )

        case .note:
            NoteEntryView(
                note: $note,
                onContinue: { step = .confirm },
                onBack: { step = .body }
            )

        case .confirm:
            confirmView
        }
    }

    private var backStepFromIntensity: Step {
        if selectedSecondary != nil { return .specific }
        return .secondary
    }

    private var shouldShowSensations: Bool {
        !bodyRegions.isEmpty && !bodyRegions.contains(.nowhere)
    }

    private var feelingPath: String {
        let parts = [selectedCore?.name, selectedSecondary?.name, selectedSpecific?.name]
            .compactMap { $0 }
        return parts.joined(separator: " › ")
    }

    private var confirmView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(feelingPath)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Intensity \(intensity)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !bodyRegions.isEmpty {
                    Text(bodyRegions.map(\.displayName).sorted().joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !bodySensations.isEmpty {
                    Text(bodySensations.map(\.displayName).sorted().joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !trimmedNote.isEmpty {
                    Text(trimmedNote)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                if didSend {
                    Label("Sent", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("New Check-In") { reset() }
                } else {
                    Button(action: sendPayload) {
                        Label("Send", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendPayload() {
        guard let core = selectedCore else { return }
        let payload = WatchCheckInPayload(
            coreID: core.id,
            coreName: core.name,
            secondaryID: selectedSecondary?.id,
            secondaryName: selectedSecondary?.name,
            specificID: selectedSpecific?.id,
            specificName: selectedSpecific?.name,
            intensity: intensity,
            bodyRegions: bodyRegions.map(\.rawValue),
            bodySensations: bodySensations.map(\.rawValue),
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        sessionClient.send(payload)
        didSend = true
    }

    private func reset() {
        step = .core
        selectedCore = nil
        selectedSecondary = nil
        selectedSpecific = nil
        intensity = 3
        bodyRegions = []
        bodySensations = []
        note = ""
        didSend = false
    }
}
