import SwiftUI

/// Title + subtitle + optional selected-feeling badge above each step.
struct StepHeader: View {
    let stepIndex: Int
    let totalSteps: Int
    let title: String
    let subtitle: String
    let selectedFeeling: EmotionSelection?
    let intensity: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            StepProgressBar(currentIndex: stepIndex, total: totalSteps)
            Text("Step \(stepIndex + 1) of \(totalSteps)")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
                .padding(.top, .OF.xs)
            Text(title)
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
            Text(subtitle)
                .font(.OF.body)
                .foregroundStyle(Color.OF.textMuted)
            if let selectedFeeling {
                SelectedFeelingBadge(selection: selectedFeeling, intensity: intensity)
            }
        }
        .padding(.top, .OF.lg)
    }
}
