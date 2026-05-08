import SwiftUI

struct MoodStep: View {
    @Binding var draft: CheckInDraft
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            Toggle(isOn: $draft.includeMoodScale) {
                Text("Include mood scale").font(.OF.bodyEmphasis)
            }
            if draft.includeMoodScale {
                VStack(alignment: .leading, spacing: .OF.md) {
                    moodSlider(title: "Energy", left: "calm", right: "activated", value: $draft.moodEnergy)
                    moodSlider(title: "Valence", left: "unpleasant", right: "pleasant", value: $draft.moodValence)
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func moodSlider(title: String, left: String, right: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            HStack {
                Text(title).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text(currentLabel(title: title, value: value.wrappedValue))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.text)
            }
            Slider(value: value, in: -1...1, step: 0.05)
                .tint(Color.OF.accent.color(for: colorScheme))
            HStack {
                Text(left).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text(right).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    private func currentLabel(title: String, value: Double) -> String {
        title == "Energy" ? MoodScale.energyBand(value) : MoodScale.valenceBand(value)
    }
}
