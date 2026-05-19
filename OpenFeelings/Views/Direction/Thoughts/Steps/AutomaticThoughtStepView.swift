import SwiftUI

/// Step 2. Required: the thought the user noticed. Continue disabled until
/// the field has non-whitespace text.
struct AutomaticThoughtStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    private var canAdvance: Bool {
        !draft.automaticThought
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("What thought went through your head?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Quote yourself if you can. Verbatim is fine.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            TextField("e.g., I'm going to embarrass myself",
                      text: $draft.automaticThought,
                      axis: .vertical)
                .lineLimit(3...8)
                .font(.OF.body)
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
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("The thought")
        .navigationBarTitleDisplayMode(.inline)
    }
}
