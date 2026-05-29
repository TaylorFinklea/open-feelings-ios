// OpenFeelings/Design/Components/OFEmptyState.swift
import SwiftUI

struct OFEmptyState: View {
    let glyph: String
    let title: String
    let bodyText: String
    var primaryAction: PrimaryAction? = nil

    struct PrimaryAction {
        let label: String
        let perform: () -> Void
    }

    var body: some View {
        VStack(spacing: .OF.lg) {
            ZStack {
                Circle()
                    .fill(Color.OF.accentSoft)
                    .frame(width: 84, height: 84)
                Image(systemName: glyph)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.OF.accent)
            }
            VStack(spacing: .OF.sm) {
                Text(title)
                    .ofTitle()
                    .foregroundStyle(Color.OF.text)
                    .multilineTextAlignment(.center)
                Text(bodyText)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .OF.lg)
            }
            if let primaryAction {
                OFButton(primaryAction.label, style: .primary, action: primaryAction.perform)
                    .padding(.horizontal, .OF.xxl)
                    .padding(.top, .OF.sm)
            }
        }
        .padding(.horizontal, .OF.lg)
        .padding(.vertical, .OF.xxl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OFEmptyState(
        glyph: "leaf.circle",
        title: "Today is open.",
        bodyText: "Tap below to name how you're feeling.",
        primaryAction: .init(label: "Start a check-in", perform: {})
    )
    .background(Color.OF.background)
}
