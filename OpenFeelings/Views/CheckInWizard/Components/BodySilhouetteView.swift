import SwiftUI

/// Calm body silhouette using the iOS `figure.arms.open` SF Symbol as the
/// figure. Each region has a small dotted hint rectangle showing where to
/// tap. Selecting a region masks an accent-colored copy of the same figure
/// to that zone, so highlights conform to the actual body shape rather
/// than rendering as floating rectangles.
///
/// "Back" doesn't appear on the front-facing figure — the parent renders
/// it as a chip beneath the silhouette alongside Everywhere / Nowhere.
struct BodySilhouetteView: View {
    @Binding var selectedRegions: Set<BodyRegion>
    let onToggle: (BodyRegion) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Tap-and-mask zone in normalized space (0...1) over the figure
    /// bounding box. Rectangles intentionally — the figure provides the
    /// curvature when used as a mask.
    private struct Zone: Hashable, Sendable {
        let region: BodyRegion
        let frame: CGRect
    }

    private let zones: [Zone] = [
        Zone(region: .head,      frame: CGRect(x: 0.42, y: 0.05, width: 0.16, height: 0.18)),
        Zone(region: .throat,    frame: CGRect(x: 0.46, y: 0.22, width: 0.08, height: 0.04)),
        Zone(region: .shoulders, frame: CGRect(x: 0.36, y: 0.26, width: 0.28, height: 0.06)),
        Zone(region: .chest,     frame: CGRect(x: 0.42, y: 0.32, width: 0.16, height: 0.13)),
        Zone(region: .stomach,   frame: CGRect(x: 0.42, y: 0.45, width: 0.16, height: 0.07)),
        Zone(region: .gut,       frame: CGRect(x: 0.42, y: 0.52, width: 0.16, height: 0.07)),
        // Hands: cover the full arm + fist (figure.arms.open arms angle outward and down).
        Zone(region: .hands,     frame: CGRect(x: 0.18, y: 0.27, width: 0.24, height: 0.22)),
        Zone(region: .hands,     frame: CGRect(x: 0.58, y: 0.27, width: 0.24, height: 0.22)),
        // Legs from hip down.
        Zone(region: .legs,      frame: CGRect(x: 0.36, y: 0.60, width: 0.14, height: 0.36)),
        Zone(region: .legs,      frame: CGRect(x: 0.50, y: 0.60, width: 0.14, height: 0.36)),
    ]

    private let canvasSize: CGFloat = 360
    private let figurePadding: CGFloat = 12

    var body: some View {
        ZStack {
            // 1. Base muted figure — always visible.
            figureImage
                .foregroundStyle(figureColor)

            // 2. Selected: accent-colored figure clipped to selected zone rectangles.
            //    Mask is rectangular but the figure provides its own shape, so
            //    highlighted pixels are always inside the body.
            figureImage
                .foregroundStyle(accentColor)
                .mask {
                    GeometryReader { geo in
                        ZStack {
                            ForEach(selectedZones, id: \.self) { zone in
                                maskRect(for: zone, in: geo.size)
                            }
                        }
                    }
                }

            // 3. Region hints: dashed outlines on every unselected zone, so
            //    the user can see where the tappable areas are.
            GeometryReader { geo in
                ZStack {
                    ForEach(unselectedZones, id: \.self) { zone in
                        outlineRect(for: zone, in: geo.size)
                    }
                }
            }

            // 4. Tap layer — invisible. `.contentShape` and `.onTapGesture`
            //    must come BEFORE `.position()` so each rectangle's hit
            //    area is its own frame, not the full canvas.
            GeometryReader { geo in
                ZStack {
                    ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                        tapZone(for: zone, in: geo.size)
                    }
                }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var figureImage: some View {
        Image(systemName: "figure.arms.open")
            .resizable()
            .scaledToFit()
            .padding(figurePadding)
    }

    private var selectedZones: [Zone] {
        zones.filter { selectedRegions.contains($0.region) }
    }

    private var unselectedZones: [Zone] {
        zones.filter { !selectedRegions.contains($0.region) }
    }

    private func maskRect(for zone: Zone, in size: CGSize) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(
                width: zone.frame.width * size.width,
                height: zone.frame.height * size.height
            )
            .position(
                x: zone.frame.midX * size.width,
                y: zone.frame.midY * size.height
            )
    }

    private func outlineRect(for zone: Zone, in size: CGSize) -> some View {
        Rectangle()
            .strokeBorder(
                outlineColor,
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
            .frame(
                width: zone.frame.width * size.width,
                height: zone.frame.height * size.height
            )
            .position(
                x: zone.frame.midX * size.width,
                y: zone.frame.midY * size.height
            )
    }

    private func tapZone(for zone: Zone, in size: CGSize) -> some View {
        Color.clear
            .frame(
                width: zone.frame.width * size.width,
                height: zone.frame.height * size.height
            )
            .contentShape(Rectangle())
            .onTapGesture { onToggle(zone.region) }
            .accessibilityElement()
            .accessibilityLabel(zone.region.displayName)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(selectedRegions.contains(zone.region) ? "Selected" : "")
            .position(
                x: zone.frame.midX * size.width,
                y: zone.frame.midY * size.height
            )
    }

    private var figureColor: Color {
        Color.OF.textMuted.color(for: colorScheme)
    }

    private var accentColor: Color {
        Color.OF.accent.color(for: colorScheme)
    }

    private var outlineColor: Color {
        Color.OF.textMuted.color(for: colorScheme).opacity(0.7)
    }
}
