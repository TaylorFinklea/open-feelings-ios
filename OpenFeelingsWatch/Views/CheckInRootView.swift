import SwiftUI

struct CheckInRootView: View {
    @Environment(WatchSessionClient.self) private var sessionClient
    @Environment(CheckInWizardState.self) private var wizard
    @Environment(WatchSettingsStore.self) private var settingsStore

    @State private var path: [Step] = []

    enum Step: Hashable {
        case sensations
        case core         // pushed-onto-stack core picker (body-first flow)
        case secondary
        case specific
        case intensity
        case note
        case confirm
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationTitle("Check In")
                .navigationDestination(for: Step.self) { destination(for: $0) }
        }
        .onAppear { applyScreenshotModeIfNeeded() }
    }

    @ViewBuilder
    private var rootView: some View {
        if screenshotRootCore {
            corePicker
        } else if settingsStore.settings.bodyFirst {
            BodyRegionPicker(
                selection: Binding(get: { wizard.bodyRegions }, set: { wizard.bodyRegions = $0 }),
                onContinue: { advanceFromBody() }
            )
        } else {
            corePicker
        }
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        switch step {
        case .sensations:
            SensationPicker(
                selection: Binding(get: { wizard.bodySensations }, set: { wizard.bodySensations = $0 }),
                onContinue: { path.append(.core) }
            )

        case .core:
            corePicker

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
                    onContinue: { path.append(.note) }
                )
            }

        case .note:
            NoteEntryView(
                note: Binding(get: { wizard.note }, set: { wizard.note = $0 }),
                onContinue: { path.append(.confirm) }
            )

        case .confirm:
            confirmView
        }
    }

    private var corePicker: some View {
        CoreFeelingPicker { core in
            wizard.core = core
            wizard.secondary = nil
            wizard.specific = nil
            path.append(.secondary)
        }
    }

    // Body-first flow: after picking body regions, branch to sensations (when
    // promoted in iOS settings) or straight to the core picker.
    private func advanceFromBody() {
        if settingsStore.settings.sensationsPromoted {
            path.append(.sensations)
        } else {
            path.append(.core)
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

    // MARK: - Screenshot mode

    /// The `-watchShot <name>` value, if the app was launched for App Store
    /// screenshot capture. Always nil in release builds.
    private static var screenshotShot: String? {
        #if DEBUG
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-watchShot"), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }

    /// In screenshot mode the feelings list is always the root, so every
    /// captured screen shares a consistent back-stack regardless of the
    /// body-first setting pushed from iOS.
    private var screenshotRootCore: Bool {
        Self.screenshotShot != nil
    }

    /// Seeds wizard state and the navigation path so a single launch lands on
    /// the requested screen without any taps. No-op outside screenshot mode.
    private func applyScreenshotModeIfNeeded() {
        guard let shot = Self.screenshotShot, path.isEmpty, wizard.core == nil else { return }
        let core = EmotionTaxonomy.cores.first { $0.name == "Happy" } ?? EmotionTaxonomy.cores[0]
        let secondary = core.secondaries.first { $0.name == "Peaceful" } ?? core.secondaries.first
        switch shot {
        case "core":
            break // corePicker is already the root
        case "secondary":
            wizard.core = core
            path = [.secondary]
        case "intensity":
            wizard.core = core
            wizard.secondary = secondary
            wizard.specific = secondary?.specifics.first
            wizard.intensity = 4
            path = [.intensity]
        case "confirm":
            wizard.core = core
            wizard.secondary = secondary
            wizard.specific = secondary?.specifics.first
            wizard.intensity = 4
            path = [.confirm]
        default:
            break
        }
    }
}
