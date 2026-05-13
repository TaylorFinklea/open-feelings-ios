import SwiftUI

/// Second drill level. The first row lets the user stop at the core feeling
/// and advance to the next step without picking a secondary — mirrors the
/// iOS app's "stop at any level" behavior.
struct SecondaryFeelingPicker: View {
    let core: EmotionCore
    var onStopAtCore: () -> Void
    var onSelect: (EmotionSecondary) -> Void

    var body: some View {
        List {
            Button(action: onStopAtCore) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: core.colorHex))
                    Text("Just \(core.name)")
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            ForEach(core.secondaries) { secondary in
                Button {
                    onSelect(secondary)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: secondary.colorHex))
                            .frame(width: 14, height: 14)
                        Text(secondary.name)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(core.name)
    }
}
