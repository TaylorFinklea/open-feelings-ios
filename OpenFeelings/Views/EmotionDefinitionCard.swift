import SwiftUI

struct EmotionDefinitionCard: View {
    let definition: EmotionDefinition
    let accent: Color
    var showsDisclaimer = true
    @State private var showsSources = false

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("\(definition.title) — clinical note".uppercased())
                .font(.OF.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Color.OF.textMuted)

            Text(definition.summary)
                .font(.system(size: 17, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.OF.text)
                .fixedSize(horizontal: false, vertical: true)

            if showsDisclaimer {
                Text(EmotionDefinitions.disclaimer)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup(isExpanded: $showsSources) {
                VStack(alignment: .leading, spacing: .OF.xs) {
                    ForEach(EmotionDefinitions.referenceSources) { source in
                        Link(source.title, destination: source.url)
                            .font(.OF.caption)
                            .foregroundStyle(Color.OF.accent)
                    }
                }
                .padding(.top, .OF.xs)
            } label: {
                Text("Sources")
                    .font(.OF.caption.weight(.semibold))
                    .foregroundStyle(Color.OF.textMuted)
            }
            .tint(Color.OF.accent)
        }
        .padding(CGFloat.OF.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
