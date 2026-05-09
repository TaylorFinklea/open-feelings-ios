import SwiftUI

/// "Where do you feel it?" — region chips with Everywhere / Nowhere as
/// italic dashed chips at the front.
struct BodyStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                specialChip(.wholeBody, label: "Everywhere")
                specialChip(.nowhere, label: "Nowhere")
                ForEach(regularRegions, id: \.self) { region in
                    OFChip(label: region.displayName, isOn: bindingFor(region))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private var regularRegions: [BodyRegion] {
        BodyRegion.allCases.filter { $0 != .wholeBody && $0 != .nowhere }
    }

    @ViewBuilder
    private func specialChip(_ region: BodyRegion, label: String) -> some View {
        Button {
            draft.toggleRegion(region)
        } label: {
            Text(label)
                .font(.OF.caption)
                .italic()
                .padding(.vertical, .OF.xs)
                .padding(.horizontal, .OF.md)
                .background(
                    draft.bodyRegions.contains(region)
                        ? AnyShapeStyle(Color.OF.accent)
                        : AnyShapeStyle(Color.OF.background)
                )
                .foregroundStyle(
                    draft.bodyRegions.contains(region)
                        ? Color.OF.surface
                        : Color.OF.accent
                )
                .overlay(
                    Capsule().stroke(Color.OF.accent,
                                     style: StrokeStyle(lineWidth: 1,
                                                        dash: draft.bodyRegions.contains(region) ? [] : [4, 3]))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func bindingFor(_ region: BodyRegion) -> Binding<Bool> {
        Binding(
            get: { draft.bodyRegions.contains(region) },
            set: { _ in draft.toggleRegion(region) }
        )
    }
}
