import SwiftUI

/// Third drill level. The first row lets the user stop at the secondary
/// feeling and continue without picking a specific.
struct SpecificFeelingPicker: View {
    let secondary: EmotionSecondary
    var onStopAtSecondary: () -> Void
    var onSelect: (EmotionSpecific) -> Void

    var body: some View {
        List {
            Button(action: onStopAtSecondary) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: secondary.colorHex))
                    Text("Just \(secondary.name)")
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            ForEach(secondary.specifics) { specific in
                Button {
                    onSelect(specific)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: specific.colorHex))
                            .frame(width: 14, height: 14)
                        Text(specific.name)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(secondary.name)
    }
}
