import SwiftUI

struct IntensityPicker: View {
    let core: EmotionCore
    @Binding var intensity: Int
    var onContinue: () -> Void

    @FocusState private var crownFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(core.name)
                .font(.headline)
            Text("Intensity")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        intensity = value
                    } label: {
                        Text("\(value)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(value == intensity ? Color(hex: core.colorHex).opacity(0.6) : Color.secondary.opacity(0.2))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Next", action: onContinue)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            Binding(
                get: { Double(intensity) },
                set: { intensity = max(1, min(5, Int($0.rounded()))) }
            ),
            from: 1, through: 5, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
        )
        .onAppear { crownFocused = true }
    }
}
