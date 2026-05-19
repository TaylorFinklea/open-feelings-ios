import SwiftUI

/// Step 6. How strong the feeling feels *after* the reframe. Reuses the
/// `intensityDotsPicker` helper defined in IntensityBeforeStepView.swift.
struct IntensityAfterStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("How strong does it feel now?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Same scale. It's OK if it didn't move.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            intensityDotsPicker(selection: $draft.intensityAfter)

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.intensityAfter == nil)
            .opacity(draft.intensityAfter == nil ? 0.4 : 1)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("After")
        .navigationBarTitleDisplayMode(.inline)
    }
}
