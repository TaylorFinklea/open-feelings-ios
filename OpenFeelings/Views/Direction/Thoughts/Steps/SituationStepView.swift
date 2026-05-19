import SwiftUI

/// Step 1 of the thought-record wizard. Optional free-text context for the
/// thought ("What was happening?"). Empty is OK — Continue is always enabled.
struct SituationStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("What was happening?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Optional. A few words is enough.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            TextField("e.g., morning standup",
                      text: $draft.situation,
                      axis: .vertical)
                .lineLimit(2...6)
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
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Thought record")
        .navigationBarTitleDisplayMode(.inline)
    }
}
