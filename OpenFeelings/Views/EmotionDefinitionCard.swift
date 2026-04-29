import SwiftUI

struct EmotionDefinitionCard: View {
    let definition: EmotionDefinition
    let accent: Color
    var showsDisclaimer = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Clinically informed meaning", systemImage: "book.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(definition.summary)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if showsDisclaimer {
                Text(EmotionDefinitions.disclaimer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
