// OpenFeelings/Design/Components/OFSectionHeader.swift
import SwiftUI

struct OFSectionHeader: View {
    let title: String
    var trailingActionTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: .OF.sm) {
            Text(title.uppercased())
                .font(.OF.caption)
                .tracking(1.0)
                .foregroundStyle(Color.OF.textMuted)
            Spacer()
            if let trailingActionTitle, let trailingAction {
                Button(trailingActionTitle, action: trailingAction)
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
        OFSectionHeader(title: "This week", trailingActionTitle: "See all") {}
    }
    .padding(.vertical)
    .background(Color.OF.background)
}
