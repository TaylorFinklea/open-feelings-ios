// OpenFeelings/Design/Components/OFSectionHeader.swift
import SwiftUI

struct OFSectionHeader: View {
    let title: String
    var trailingAction: TrailingAction?

    struct TrailingAction {
        let title: String
        let perform: () -> Void
    }

    var body: some View {
        HStack(spacing: .OF.sm) {
            Text(title.uppercased())
                .font(.OF.caption)
                .tracking(1.0)
                .foregroundStyle(Color.OF.textMuted)
                .accessibilityLabel(title)
            Spacer()
            if let action = trailingAction {
                Button(action.title, action: action.perform)
                    .font(.OF.caption.weight(.medium))
                    .foregroundStyle(Color.OF.accent)
            }
        }
        .padding(.horizontal, .OF.lg)
        .padding(.bottom, .OF.xs)
    }
}

#Preview {
    VStack(spacing: 0) {
        OFSectionHeader(title: "Today")
        OFSectionHeader(title: "This week",
                        trailingAction: .init(title: "See all") {})
    }
    .padding(.vertical)
    .background(Color.OF.background)
}
