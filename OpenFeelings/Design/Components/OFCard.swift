// OpenFeelings/Design/Components/OFCard.swift
import SwiftUI

struct OFCard<Content: View>: View {
    var padding: CGFloat = .OF.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: .OF.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: .OF.Radius.card, style: .continuous)
                    .stroke(Color.OF.divider.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}

#Preview {
    VStack(spacing: .OF.lg) {
        OFCard {
            Text("Hello")
        }
        OFCard(padding: .OF.md) {
            Text("Tighter")
        }
    }
    .padding()
    .background(Color.OF.background)
}
