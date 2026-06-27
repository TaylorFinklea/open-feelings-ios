import SwiftUI

/// "How strong?" — five tappable circles that ramp in size. Tapping a circle
/// sets intensity to that value; tapping the same circle again clears it.
/// Filled circles take the selected emotion's core color; the chosen level
/// also gets a soft wash halo.
struct StrengthStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            IntensityDots(draft: $draft)
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
}
