import SwiftUI

/// Tappable silhouette of a person. Each region maps to a tap zone overlay;
/// active regions are filled with the accent color. "Back" is not on the
/// silhouette — the parent renders it as a chip below.
struct BodySilhouetteView: View {
    @Binding var selectedRegions: Set<BodyRegion>

    private struct Zone {
        let region: BodyRegion
        let frame: CGRect      // in normalized space (0...1)
    }

    private let zones: [Zone] = [
        Zone(region: .head,      frame: CGRect(x: 0.40, y: 0.04, width: 0.20, height: 0.13)),
        Zone(region: .throat,    frame: CGRect(x: 0.45, y: 0.18, width: 0.10, height: 0.04)),
        Zone(region: .chest,     frame: CGRect(x: 0.30, y: 0.23, width: 0.40, height: 0.14)),
        Zone(region: .stomach,   frame: CGRect(x: 0.32, y: 0.38, width: 0.36, height: 0.08)),
        Zone(region: .gut,       frame: CGRect(x: 0.32, y: 0.46, width: 0.36, height: 0.08)),
        Zone(region: .shoulders, frame: CGRect(x: 0.20, y: 0.21, width: 0.60, height: 0.04)),
        Zone(region: .hands,     frame: CGRect(x: 0.04, y: 0.55, width: 0.16, height: 0.10)),
        Zone(region: .legs,      frame: CGRect(x: 0.30, y: 0.66, width: 0.40, height: 0.30))
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                outline(in: geo.size)

                ForEach(zones, id: \.region) { zone in
                    zoneView(zone, in: geo.size)
                }
            }
        }
        .frame(height: 320)
    }

    @ViewBuilder
    private func zoneView(_ zone: Zone, in size: CGSize) -> some View {
        let rect = denormalize(zone.frame, in: size)
        let isOn = selectedRegions.contains(zone.region)
        RoundedRectangle(cornerRadius: 8)
            .fill(isOn ? AnyShapeStyle(Color.OF.accent.color(for: .light).opacity(0.5))
                       : AnyShapeStyle(Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? AnyShapeStyle(Color.OF.accent.color(for: .light))
                                 : AnyShapeStyle(Color.OF.divider),
                            style: StrokeStyle(lineWidth: 1,
                                               dash: isOn ? [] : [3, 3]))
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .accessibilityLabel(zone.region.displayName)
            .accessibilityAddTraits(.isButton)
            .onTapGesture { toggle(zone.region) }
    }

    private func outline(in size: CGSize) -> some View {
        Path { p in
            // Head
            let head = CGRect(x: size.width * 0.40, y: size.height * 0.04,
                              width: size.width * 0.20, height: size.width * 0.20)
            p.addEllipse(in: head)
            // Neck
            p.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.18))
            p.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.21))
            // Shoulders
            p.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.80, y: size.height * 0.22))
            // Torso
            p.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.22))
            // Arms
            p.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.10, y: size.height * 0.60))
            p.move(to: CGPoint(x: size.width * 0.78, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.90, y: size.height * 0.60))
            // Legs
            p.move(to: CGPoint(x: size.width * 0.36, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.36, y: size.height * 0.96))
            p.move(to: CGPoint(x: size.width * 0.64, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.64, y: size.height * 0.96))
        }
        .stroke(Color.OF.textMuted, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    private func denormalize(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    private func toggle(_ region: BodyRegion) {
        if selectedRegions.contains(region) {
            selectedRegions.remove(region)
        } else {
            selectedRegions.insert(region)
        }
    }
}
