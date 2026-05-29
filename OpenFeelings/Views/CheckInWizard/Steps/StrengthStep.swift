import SwiftUI

/// "How strong?" — five tappable circles that ramp in size. Tapping a circle
/// sets intensity to that value; tapping the same circle again clears it.
/// Filled circles take the selected emotion's core color; the chosen level
/// also gets a soft wash halo.
struct StrengthStep: View {
    @Binding var draft: CheckInDraft

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Graduated diameters for levels 1...5 (28pt → 48pt).
    private let sizes: [CGFloat] = [28, 33, 38, 43, 48]

    /// Selected emotion's core color, or the warm accent when nothing is picked.
    private var coreColor: Color {
        if let id = draft.selection?.core.id {
            return EmotionColorPalette.color(coreID: id, depth: .core, scheme: colorScheme)
        }
        return Color.OF.accent.color(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            HStack(spacing: .OF.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        toggle(value)
                    } label: {
                        circle(for: value)
                            .frame(minWidth: 44, minHeight: 44)   // ≥44pt hit target
                            .contentShape(Rectangle())
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

    @ViewBuilder
    private func circle(for value: Int) -> some View {
        let size = sizes[value - 1]
        ZStack {
            // Soft wash halo behind the chosen level. Under reduced
            // transparency the translucent wash drops out and the ring goes
            // near-solid so the cue stays visible.
            if isSelectedLevel(value) {
                Circle()
                    .fill(coreColor.opacity(reduceTransparency ? 0 : 0.18))
                    .frame(width: size + 10, height: size + 10)
                Circle()
                    .stroke(coreColor.opacity(reduceTransparency ? 0.9 : 0.4), lineWidth: 2)
                    .frame(width: size + 10, height: size + 10)
            }
            Circle()
                .fill(isFilled(value) ? AnyShapeStyle(coreColor)
                                      : AnyShapeStyle(Color.OF.divider))
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
