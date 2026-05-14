import SwiftUI

struct CheckInRootView: View {
    @Environment(WatchSessionClient.self) private var sessionClient

    // Drives both flow advancement (append to push) and back-navigation (system
    // edge-swipe and nav-bar chevron both pop the last entry automatically).
    @State private var path: [Step] = []

    @State private var selectedCore: EmotionCore?
    @State private var selectedSecondary: EmotionSecondary?
    @State private var selectedSpecific: EmotionSpecific?
    @State private var intensity: Int = 3
    @State private var bodyRegions: Set<BodyRegion> = []
    @State private var bodySensations: Set<BodySensation> = []
    @State private var note: String = ""
    @State private var didSend: Bool = false

    // Carrying the drill value INSIDE the path entry (instead of reading it
    // out of @State at destination time) avoids a watchOS NavigationStack
    // race where the destination resolves before the @State write propagates,
    // which manifested as a blank screen after picking a core.
    enum Step: Hashable {
        case secondary(EmotionCore)
        case specific(EmotionSecondary)
        case intensity
        case body
        case sensations
        case note
        case confirm
    }

    var body: some View {
        NavigationStack(path: $path) {
            CoreFeelingPicker { core in
                selectedCore = core
                selectedSecondary = nil
                selectedSpecific = nil
                path.append(.secondary(core))
            }
            .navigationTitle("Check In")
            .navigationDestination(for: Step.self) { destination(for: $0) }
        }
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        switch step {
        case .secondary(let core):
            SecondaryFeelingPicker(
                core: core,
                onStopAtCore: { path.append(.intensity) },
                onSelect: { secondary in
                    selectedSecondary = secondary
                    selectedSpecific = nil
                    path.append(.specific(secondary))
                }
            )

        case .specific(let secondary):
            SpecificFeelingPicker(
                secondary: secondary,
                onStopAtSecondary: { path.append(.intensity) },
                onSelect: { specific in
                    selectedSpecific = specific
                    path.append(.intensity)
                }
            )

        case .intensity:
            if let core = selectedCore {
                IntensityPicker(
                    core: core,
                    intensity: $intensity,
                    onContinue: { path.append(.body) }
                )
            }

        case .body:
            BodyRegionPicker(
                selection: $bodyRegions,
                onContinue: { path.append(shouldShowSensations ? .sensations : .note) }
            )

        case .sensations:
            SensationPicker(
                selection: $bodySensations,
                onContinue: { path.append(.note) }
            )

        case .note:
            NoteEntryView(
                note: $note,
                onContinue: { path.append(.confirm) }
            )

        case .confirm:
            confirmView
        }
    }

    private var shouldShowSensations: Bool {
        !bodyRegions.isEmpty && !bodyRegions.contains(.nowhere)
    }

    private var feelingPath: String {
        [selectedCore?.name, selectedSecondary?.name, selectedSpecific?.name]
            .compactMap { $0 }
            .joined(separator: " › ")
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
        .navigationTitle("Review")
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
        path = []
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
