import SwiftUI

struct OFButton: View {
    enum Style: Sendable { case primary, secondary, ghost, destructive }

    let title: String
    let style: Style
    let action: () -> Void

    init(_ title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.OF.bodyEmphasis)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: .OF.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.OF.quick, value: style)
    }

    private var foreground: AnyShapeStyle {
        switch style {
        case .primary:           AnyShapeStyle(Color.OF.textOnAccent)
        case .secondary, .ghost: AnyShapeStyle(Color.OF.accent)
        case .destructive:       AnyShapeStyle(Color.white)
        }
    }

    private var background: AnyShapeStyle {
        switch style {
        case .primary:     AnyShapeStyle(Color.OF.accent)
        case .secondary:   AnyShapeStyle(Color.OF.accentSoft)
        case .ghost:       AnyShapeStyle(Color.clear)
        case .destructive: AnyShapeStyle(Color.red.opacity(0.9))
        }
    }
}

#Preview {
    VStack(spacing: .OF.md) {
        OFButton("Save check-in", style: .primary) {}
        OFButton("Notify me", style: .secondary) {}
        OFButton("Cancel", style: .ghost) {}
        OFButton("Delete", style: .destructive) {}
    }
    .padding()
    .background(Color.OF.background)
}
