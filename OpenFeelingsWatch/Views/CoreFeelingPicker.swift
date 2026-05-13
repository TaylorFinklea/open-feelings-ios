import SwiftUI

struct CoreFeelingPicker: View {
    var onSelect: (EmotionCore) -> Void

    var body: some View {
        List(EmotionTaxonomy.cores) { core in
            Button {
                onSelect(core)
            } label: {
                HStack {
                    Circle()
                        .fill(Color(hex: core.colorHex))
                        .frame(width: 16, height: 16)
                    Text(core.name)
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }
}
