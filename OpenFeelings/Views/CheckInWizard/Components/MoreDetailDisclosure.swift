import SwiftUI

/// Collapsible "+ More detail" container. Holds a stack of optional cards;
/// they remain hidden until the user taps the disclosure header.
struct MoreDetailDisclosure<Content: View>: View {
    @State private var isExpanded = false
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            Button {
                withAnimation(.OF.gentle) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(isExpanded ? "− More detail" : "+ More detail")
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(Color.OF.text)
                    Spacer()
                }
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                            .stroke(Color.OF.divider, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}
