import SwiftUI

/// "How strong?" — five tappable dots. Tapping a dot sets intensity to that
/// value; tapping the same dot again clears it.
struct StrengthStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            HStack(spacing: .OF.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        toggle(value)
                    } label: {
                        Circle()
                            .fill(isFilled(value) ? AnyShapeStyle(Color.OF.accent)
                                                  : AnyShapeStyle(Color.OF.divider))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Intensity \(value)")
                    .accessibilityAddTraits(isFilled(value) ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Text("Just noticing")
                    .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text("Strong")
                    .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            }
        }
        .padding(CGFloat.OF.lg)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func isFilled(_ value: Int) -> Bool {
        draft.includeIntensity && Int(draft.intensity.rounded()) >= value
    }

    private func toggle(_ value: Int) {
        if draft.includeIntensity && Int(draft.intensity.rounded()) == value {
            draft.includeIntensity = false
            draft.intensity = 3
        } else {
            draft.includeIntensity = true
            draft.intensity = Double(value)
        }
    }
}
