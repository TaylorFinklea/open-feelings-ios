import SwiftUI

struct CheckInRootView: View {
    @Environment(WatchSessionClient.self) private var sessionClient

    // Hoisted to the app entry so its lifecycle never gets tangled with the
    // navigation stack's view recreation.
    @Environment(CheckInWizardState.self) private var wizard

    @State private var path: [Step] = []

    enum Step: Hashable {
        case secondary
        case specific
        case intensity
        case body
        case sensations
        case note
        case confirm
    }

    var body: some View {
        NavigationStack(path: $path) {
            CoreFeelingPicker { core in
                wizard.core = core
                wizard.secondary = nil
                wizard.specific = nil
                path.append(.secondary)
            }
            .navigationTitle("Check In")
            .navigationDestination(for: Step.self) { destination(for: $0) }
        }
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        switch step {
        case .secondary:
            if let core = wizard.core {
                SecondaryFeelingPicker(
                    core: core,
                    onStopAtCore: { path.append(.intensity) },
                    onSelect: { secondary in
                        wizard.secondary = secondary
                        wizard.specific = nil
                        path.append(.specific)
                    }
                )
            }

        case .specific:
            if let secondary = wizard.secondary {
                SpecificFeelingPicker(
                    secondary: secondary,
                    onStopAtSecondary: { path.append(.intensity) },
                    onSelect: { specific in
                        wizard.specific = specific
                        path.append(.intensity)
                    }
                )
            }

        case .intensity:
            if let core = wizard.core {
                IntensityPicker(
                    core: core,
                    intensity: Binding(get: { wizard.intensity }, set: { wizard.intensity = $0 }),
                    onContinue: { path.append(.body) }
                )
            }

        case .body:
            BodyRegionPicker(
                selection: Binding(get: { wizard.bodyRegions }, set: { wizard.bodyRegions = $0 }),
                onContinue: { path.append(wizard.shouldShowSensations ? .sensations : .note) }
            )

        case .sensations:
            SensationPicker(
                selection: Binding(get: { wizard.bodySensations }, set: { wizard.bodySensations = $0 }),
                onContinue: { path.append(.note) }
            )

        case .note:
            NoteEntryView(
                note: Binding(get: { wizard.note }, set: { wizard.note = $0 }),
                onContinue: { path.append(.confirm) }
            )

        case .confirm:
            confirmView
        }
    }

    private var confirmView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(wizard.feelingPath)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Intensity \(wizard.intensity)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !wizard.bodyRegions.isEmpty {
                    Text(wizard.bodyRegions.map(\.displayName).sorted().joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !wizard.bodySensations.isEmpty {
                    Text(wizard.bodySensations.map(\.displayName).sorted().joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !wizard.trimmedNote.isEmpty {
                    Text(wizard.trimmedNote)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                if wizard.didSend {
                    Label("Sent", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("New Check-In") { startOver() }
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

    private func sendPayload() {
        guard let core = wizard.core else { return }
        let payload = WatchCheckInPayload(
            coreID: core.id,
            coreName: core.name,
            secondaryID: wizard.secondary?.id,
            secondaryName: wizard.secondary?.name,
            specificID: wizard.specific?.id,
            specificName: wizard.specific?.name,
            intensity: wizard.intensity,
            bodyRegions: wizard.bodyRegions.map(\.rawValue),
            bodySensations: wizard.bodySensations.map(\.rawValue),
            note: wizard.trimmedNote.isEmpty ? nil : wizard.trimmedNote
        )
        sessionClient.send(payload)
        wizard.didSend = true
    }

    private func startOver() {
        wizard.reset()
        path = []
    }
}
