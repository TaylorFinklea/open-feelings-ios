import SwiftUI

/// Soft pill showing the user's chosen feeling (and intensity, if set).
struct SelectedFeelingBadge: View {
    let selection: EmotionSelection
    let intensity: Int?

    var body: some View {
        HStack(spacing: .OF.sm) {
            Circle()
                .fill(Color.OF.core(selection.core.id))
                .frame(width: 12, height: 12)
            Text(selection.title)
                .font(.OF.bodyEmphasis)
                .foregroundStyle(Color.OF.text)
            if let intensity {
                Text("·").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Text("\(intensity)").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            }
            if !selection.pathTitle.isEmpty {
                Text("·").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Text(selection.pathTitle)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, .OF.xs)
        .padding(.horizontal, .OF.md)
        .background(Color.OF.surface, in: Capsule())
        .overlay(Capsule().stroke(Color.OF.divider, lineWidth: 1))
    }
}
