import SwiftUI

/// Step 5. Required: a balanced/alternative way of looking at the situation.
/// Continue disabled until non-empty.
struct BalancedThoughtStepView: View {
    @Bindable var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    private var canAdvance: Bool {
        !draft.balancedThought
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("Is there a different way of looking at it?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Not a forced positive — just a fairer reading.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            TextField("e.g., I've handled tougher meetings before",
                      text: $draft.balancedThought,
                      axis: .vertical)
                .lineLimit(3...8)
                .font(.OF.body)
                .accessibilityIdentifier("thought-record.field.balanced")
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.4)
            .accessibilityIdentifier("thought-record.continue")
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("A balanced view")
        .navigationBarTitleDisplayMode(.inline)
    }
}
