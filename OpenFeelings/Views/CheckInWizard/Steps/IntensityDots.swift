import SwiftUI

/// The five tappable intensity circles (1...5), bound to a CheckInDraft.
/// Tapping a circle sets intensity to that value; tapping the selected circle
/// again clears it. Extracted from StrengthStep so QuickEntry can reuse it.
struct IntensityDots: View {
    @Binding var draft: CheckInDraft

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let sizes: [CGFloat] = [28, 33, 38, 43, 48]

    private var coreColor: Color {
        if let id = draft.selection?.core.id {
            return EmotionColorPalette.color(coreID: id, depth: .core, scheme: colorScheme)
        }
        return Color.OF.accent.color(for: colorScheme)
    }

    var body: some View {
        HStack(spacing: .OF.sm) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    toggle(value)
                } label: {
                    circle(for: value)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Intensity \(value)")
                .accessibilityAddTraits(isFilled(value) ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func circle(for value: Int) -> some View {
        let size = sizes[value - 1]
        ZStack {
            if isSelectedLevel(value) {
                Circle()
                    .fill(coreColor.opacity(reduceTransparency ? 0 : 0.18))
                    .frame(width: size + 10, height: size + 10)
                Circle()
                    .stroke(coreColor.opacity(reduceTransparency ? 0.9 : 0.4), lineWidth: 2)
                    .frame(width: size + 10, height: size + 10)
            }
            Circle()
                .fill(isFilled(value) ? AnyShapeStyle(coreColor) : AnyShapeStyle(Color.OF.divider))
                .frame(width: size, height: size)
        }
    }

    private func isFilled(_ value: Int) -> Bool {
        draft.includeIntensity && Int(draft.intensity.rounded()) >= value
    }

    private func isSelectedLevel(_ value: Int) -> Bool {
        draft.includeIntensity && Int(draft.intensity.rounded()) == value
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
