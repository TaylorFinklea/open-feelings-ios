import SwiftUI

/// Step 3. How strong did the feeling feel before reframing. Five-dot
/// picker matching `StrengthStep`'s visual; Continue gated on a non-nil
/// selection.
struct IntensityBeforeStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("How strong was the feeling?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("1 is barely noticing it, 5 is at full force.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            intensityDotsPicker(selection: $draft.intensityBefore)

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.intensityBefore == nil)
            .opacity(draft.intensityBefore == nil ? 0.4 : 1)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Before")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Five tappable dots. Tap a dot to select; tap the same dot again to clear.
/// Mirrors the toggling behavior of `StrengthStep`. Named `intensityDotsPicker`
/// (not `intensityDots`) to avoid visual confusion with the private
/// `intensityDots(intensity:)` helpers already in `TodayView` and
/// `HistoryView` which render a non-interactive row.
@ViewBuilder
func intensityDotsPicker(selection: Binding<Int?>) -> some View {
    VStack(spacing: CGFloat.OF.sm) {
        HStack(spacing: CGFloat.OF.sm) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    if selection.wrappedValue == value {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = value
                    }
                } label: {
                    Circle()
                        .fill(intensityDotIsFilled(value: value, selection: selection.wrappedValue)
                              ? AnyShapeStyle(Color.OF.accent)
                              : AnyShapeStyle(Color.OF.divider))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Intensity \(value)")
                .accessibilityAddTraits(
                    selection.wrappedValue == value ? .isSelected : []
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        HStack {
            Text("Just noticing")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            Spacer()
            Text("At full force")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
        }
    }
    .padding(CGFloat.OF.lg)
    .background(Color.OF.surface,
                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
}

private func intensityDotIsFilled(value: Int, selection: Int?) -> Bool {
    guard let selection else { return false }
    return value <= selection
}
