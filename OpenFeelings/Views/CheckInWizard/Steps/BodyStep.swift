import SwiftData
import SwiftUI

/// "Where do you feel it?" — region chips by default; a stylized body
/// silhouette is available as a Settings opt-in.
struct BodyStep: View {
    @Binding var draft: CheckInDraft
    @AppStorage("checkInBodyView") private var bodyView: String = "chips"
    @Query(sort: \CustomBodyRegion.createdAt) private var customRegions: [CustomBodyRegion]

    var body: some View {
        switch bodyView {
        case "silhouette" where FeatureFlags.silhouetteBodyView:
            silhouetteLayout
        default:
            chipsLayout
        }
    }

    // MARK: - Chips layout

    private var chipsLayout: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
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

            if !customRegions.isEmpty {
                customRegionsCard
            }
        }
    }

    private var customRegionsCard: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Your regions")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(customRegions) { region in
                    OFChip(label: region.name, isOn: bindingFor(customID: region.id))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    // MARK: - Silhouette layout

    private var silhouetteLayout: some View {
        VStack(spacing: .OF.lg) {
            BodySilhouetteView(
                selectedRegions: silhouetteBinding,
                onToggle: { region in draft.toggleRegion(region) }
            )
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                OFChip(label: "Back", isOn: bindingFor(.back))
                specialChip(.wholeBody, label: "Everywhere")
                specialChip(.nowhere, label: "Nowhere")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// The silhouette view manages its own selected set; we bridge it back
    /// through `draft.toggleRegion` so exclusivity rules apply.
    private var silhouetteBinding: Binding<Set<BodyRegion>> {
        Binding(
            get: { draft.bodyRegions },
            set: { newValue in
                let added = newValue.subtracting(draft.bodyRegions)
                let removed = draft.bodyRegions.subtracting(newValue)
                for region in added { draft.toggleRegion(region) }
                for region in removed { draft.toggleRegion(region) }
            }
        )
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
        .accessibilityAddTraits(draft.bodyRegions.contains(region) ? .isSelected : [])
        .accessibilityIdentifier(OFChip.identifier(for: label))
    }

    private func bindingFor(_ region: BodyRegion) -> Binding<Bool> {
        Binding(
            get: { draft.bodyRegions.contains(region) },
            set: { _ in draft.toggleRegion(region) }
        )
    }

    private func bindingFor(customID id: UUID) -> Binding<Bool> {
        Binding(
            get: { draft.customBodyRegionIDs.contains(id) },
            set: { _ in draft.toggleCustomRegion(id) }
        )
    }
}
