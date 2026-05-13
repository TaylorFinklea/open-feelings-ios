import SwiftUI

/// "How does it feel?" — multi-select sensation toggles. Only reached when
/// at least one body region (other than "Nowhere") was selected.
struct SensationPicker: View {
    @Binding var selection: Set<BodySensation>
    var onContinue: () -> Void

    var body: some View {
        List {
            ForEach(BodySensation.allCases) { sensation in
                Button {
                    if selection.contains(sensation) {
                        selection.remove(sensation)
                    } else {
                        selection.insert(sensation)
                    }
                } label: {
                    HStack {
                        Image(systemName: selection.contains(sensation) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.contains(sensation) ? Color.accentColor : Color.secondary)
                        Text(sensation.displayName)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            Section {
                Button(action: onContinue) {
                    Text(selection.isEmpty ? "Skip" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("How")
    }
}
