import SwiftUI

struct CheckInRootView: View {
    @Environment(WatchSessionClient.self) private var sessionClient
    @State private var step: Step = .feeling
    @State private var selectedCore: EmotionCore?
    @State private var intensity: Int = 3
    @State private var note: String = ""
    @State private var didSend: Bool = false

    enum Step: Hashable {
        case feeling
        case intensity
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
        case .feeling:
            CoreFeelingPicker { core in
                selectedCore = core
                step = .intensity
            }
        case .intensity:
            if let core = selectedCore {
                IntensityPicker(
                    core: core,
                    intensity: $intensity,
                    onContinue: { step = .note },
                    onBack: { step = .feeling }
                )
            }
        case .note:
            NoteEntryView(
                note: $note,
                onContinue: { step = .confirm },
                onBack: { step = .intensity }
            )
        case .confirm:
            confirmView
        }
    }

    private var confirmView: some View {
        VStack(spacing: 12) {
            if let core = selectedCore {
                Text(core.name)
                    .font(.title3)
                Text("Intensity \(intensity)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(note)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }
            if didSend {
                Label("Sent", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    sendPayload()
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            if didSend {
                Button("New Check-In") { reset() }
            }
        }
        .padding()
    }

    private func sendPayload() {
        guard let core = selectedCore else { return }
        let payload = WatchCheckInPayload(
            coreID: core.id,
            coreName: core.name,
            intensity: intensity,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        )
        sessionClient.send(payload)
        didSend = true
    }

    private func reset() {
        step = .feeling
        selectedCore = nil
        intensity = 3
        note = ""
        didSend = false
    }
}
