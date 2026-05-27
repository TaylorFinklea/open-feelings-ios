import SwiftUI

/// Step 4. Multi-select chips for the 8 thinking patterns. Tap toggles
/// selection; long-press surfaces the pattern's description in an
/// `.popover`. Selection is optional — Continue always enabled.
struct PatternsStepView: View {
    @Bindable var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    @State private var describing: ThinkingPattern?

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("Notice any thinking patterns?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Pick zero or more. Long-press a chip for a description.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: CGFloat.OF.md)],
                      spacing: CGFloat.OF.md) {
                ForEach(ThinkingPattern.allCases) { pattern in
                    chip(for: pattern)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("thought-record.continue")
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Patterns")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func chip(for pattern: ThinkingPattern) -> some View {
        let selected = draft.patterns.contains(pattern)
        Button {
            toggle(pattern)
        } label: {
            HStack(spacing: CGFloat.OF.xs) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected
                        ? AnyShapeStyle(Color.OF.accent)
                        : AnyShapeStyle(Color.OF.textMuted))
                Text(pattern.displayName)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, CGFloat.OF.md)
            .background(
                selected
                    ? AnyShapeStyle(Color.OF.accent.opacity(0.12))
                    : AnyShapeStyle(Color.OF.surface),
                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                    .stroke(selected
                        ? AnyShapeStyle(Color.OF.accent.opacity(0.45))
                        : AnyShapeStyle(Color.OF.divider),
                            lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pattern.\(pattern.rawValue)")
        .onLongPressGesture {
            describing = pattern
        }
        .popover(item: $describing) { pattern in
            VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
                Text(pattern.displayName)
                    .font(.OF.headline)
                Text(pattern.description)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
            }
            .padding(CGFloat.OF.md)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func toggle(_ pattern: ThinkingPattern) {
        if let idx = draft.patterns.firstIndex(of: pattern) {
            draft.patterns.remove(at: idx)
        } else {
            draft.patterns.append(pattern)
        }
    }
}
