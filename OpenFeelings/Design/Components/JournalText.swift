// OpenFeelings/Design/Components/JournalText.swift
import SwiftUI

/// Renders a multi-paragraph journal entry preserved from a FeelingLog's
/// `note` field. Italic, leading rule, muted-text quote treatment. Defaults
/// to a 3-line preview with a "Show more / less" toggle for long entries.
struct JournalText: View {
    let text: String
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text(text)
                .font(.OF.body.italic())
                .foregroundStyle(Color.OF.textMuted)
                .lineLimit(expanded ? nil : 3)
                .padding(.leading, .OF.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.OF.divider)
                        .frame(width: 2)
                }

            if needsToggle {
                Button(expanded ? "Show less" : "Show more") {
                    if reduceMotion {
                        expanded.toggle()
                    } else {
                        withAnimation(.OF.quick) { expanded.toggle() }
                    }
                }
                .font(.OF.caption.weight(.medium))
                .foregroundStyle(Color.OF.accent)
                .accessibilityHint(expanded ? "Collapses the journal entry" : "Expands the journal entry")
            }
        }
        .padding(.top, 2)
    }

    private var needsToggle: Bool {
        text.count > 140 || text.contains("\n")
    }
}

#Preview("Short note") {
    JournalText(text: "A short journal entry.")
        .padding()
        .background(Color.OF.background)
}

#Preview("Long entry") {
    JournalText(text: """
        I had this rush of anxiety before the team standup. Felt like \
        there was a knot in my chest that wouldn't loosen until I named it.

        Realizing I'd been holding my breath the whole morning. The deadline \
        on Thursday is bigger in my head than it actually is.
        """)
        .padding()
        .background(Color.OF.background)
}
