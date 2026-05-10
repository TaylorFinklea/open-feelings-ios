import SwiftUI

/// Settings → Check In flow. Houses picker style, Body First,
/// and the per-dimension promote-to-step toggles.
struct CheckInFlowSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("checkInMode") private var pickerStyle = "Wizard"
    @AppStorage("checkInBodyFirst") private var bodyFirst = true
    @AppStorage("checkInBodyView") private var bodyView = "chips"
    @AppStorage("checkInPromotedSteps") private var promotedRaw = "strength"

    var body: some View {
        Form {
            Section("Picker style") {
                Picker("Picker", selection: $pickerStyle) {
                    Text("Wizard").tag("Wizard")
                    Text("Wheel").tag("Wheel")
                }
                .pickerStyle(.segmented)
            }

            Section("Body") {
                Toggle("Body First", isOn: $bodyFirst)
                if FeatureFlags.silhouetteBodyView {
                    Picker("Body view", selection: $bodyView) {
                        Text("Chips").tag("chips")
                        Text("Silhouette").tag("silhouette")
                    }
                }
            }

            Section("Steps") {
                Text("Promote optional dimensions to first-class steps. Anything left off stays accessible via '+ More detail' on the final step.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                ForEach(promotableKinds, id: \.self) { kind in
                    Toggle(label(for: kind), isOn: bindingFor(kind))
                }
            }
        }
        .navigationTitle("Check In flow")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
    }

    private var promotableKinds: [CheckInStepKind] {
        [.sensations, .strength, .context, .triggers, .coping, .mood]
    }

    private func label(for kind: CheckInStepKind) -> String {
        switch kind {
        case .sensations: "Sensations"
        case .strength:   "Strength"
        case .context:    "Context"
        case .triggers:   "Triggers"
        case .coping:     "Coping"
        case .mood:       "Mood scale"
        default:          kind.storageKey.capitalized
        }
    }

    private func bindingFor(_ kind: CheckInStepKind) -> Binding<Bool> {
        Binding(
            get: { Set(CheckInStepKind.parseList(promotedRaw)).contains(kind) },
            set: { isOn in
                var current = Set(CheckInStepKind.parseList(promotedRaw))
                if isOn { current.insert(kind) } else { current.remove(kind) }
                let ordered: [CheckInStepKind] = [.sensations, .strength, .context, .triggers, .coping, .mood]
                    .filter { current.contains($0) }
                promotedRaw = CheckInStepKind.encodeList(ordered)
            }
        )
    }
}
