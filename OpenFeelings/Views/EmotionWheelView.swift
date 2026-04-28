import SwiftUI

struct WheelCheckInView: View {
    @Binding var selection: EmotionSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap the wheel")
                .font(.title3.weight(.semibold))

            EmotionWheelView(selection: $selection)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel("Emotion wheel")

            Text("The center ring picks a broad feeling. The middle ring narrows it. The outer ring chooses the specific feeling to save.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct EmotionWheelView: View {
    @Binding var selection: EmotionSelection?

    private let innerOuter: CGFloat = 0.32
    private let middleOuter: CGFloat = 0.62
    private let wheelStart = -90.0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let rect = CGRect(
                x: (proxy.size.width - side) / 2,
                y: (proxy.size.height - side) / 2,
                width: side,
                height: side
            )

            ZStack {
                ForEach(Array(EmotionTaxonomy.cores.enumerated()), id: \.element.id) { coreIndex, core in
                    coreSegments(core: core, coreIndex: coreIndex, rect: rect)
                }
                selectionRing(rect: rect)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        selection = selection(at: value.location, in: rect)
                    }
            )
        }
    }

    @ViewBuilder
    private func coreSegments(core: EmotionCore, coreIndex: Int, rect: CGRect) -> some View {
        let coreStart = wheelStart + Double(coreIndex) * 45
        let coreEnd = coreStart + 45
        let baseColor = Color(hex: core.colorHex)

        AnnularSegment(startAngle: coreStart, endAngle: coreEnd, innerRatio: 0, outerRatio: innerOuter)
            .fill(baseColor.opacity(0.92))

        wheelLabel(core.name, angle: coreStart + 22.5, radiusRatio: 0.2, rect: rect, size: 13, weight: .semibold)

        ForEach(Array(core.secondaries.enumerated()), id: \.element.id) { secondaryIndex, secondary in
            let secondaryStart = coreStart + Double(secondaryIndex) * 11.25
            let secondaryEnd = secondaryStart + 11.25

            AnnularSegment(startAngle: secondaryStart, endAngle: secondaryEnd, innerRatio: innerOuter, outerRatio: middleOuter)
                .fill(baseColor.opacity(0.7))

            wheelLabel(secondary.name, angle: secondaryStart + 5.625, radiusRatio: 0.47, rect: rect, size: 9, weight: .medium)

            ForEach(Array(secondary.specifics.enumerated()), id: \.element.id) { specificIndex, specific in
                let specificStart = secondaryStart + Double(specificIndex) * 3.75
                let specificEnd = specificStart + 3.75

                AnnularSegment(startAngle: specificStart, endAngle: specificEnd, innerRatio: middleOuter, outerRatio: 1)
                    .fill(baseColor.opacity(0.48))

                wheelLabel(specific.name, angle: specificStart + 1.875, radiusRatio: 0.82, rect: rect, size: 6.5, weight: .regular)
            }
        }

        Circle()
            .stroke(.primary.opacity(0.14), lineWidth: 0.5)
            .frame(width: rect.width * innerOuter, height: rect.height * innerOuter)
            .position(x: rect.midX, y: rect.midY)

        Circle()
            .stroke(.primary.opacity(0.14), lineWidth: 0.5)
            .frame(width: rect.width * middleOuter, height: rect.height * middleOuter)
            .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private func selectionRing(rect: CGRect) -> some View {
        if let selection {
            let angles = angles(for: selection)
            let ratios: (inner: CGFloat, outer: CGFloat) = if selection.specific != nil {
                (middleOuter, 1)
            } else if selection.secondary != nil {
                (innerOuter, middleOuter)
            } else {
                (0, innerOuter)
            }

            AnnularSegment(startAngle: angles.start, endAngle: angles.end, innerRatio: ratios.inner, outerRatio: ratios.outer)
                .stroke(.primary, lineWidth: 2)
                .shadow(radius: 1)
        }
    }

    private func wheelLabel(
        _ text: String,
        angle: Double,
        radiusRatio: CGFloat,
        rect: CGRect,
        size: CGFloat,
        weight: Font.Weight
    ) -> some View {
        let point = point(angle: angle, radiusRatio: radiusRatio, rect: rect)
        let normalized = normalizedDegrees(angle)
        let rotation = normalized > 90 && normalized < 270 ? angle + 270 : angle + 90

        return Text(text)
            .font(.system(size: size, weight: weight))
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .foregroundStyle(.primary)
            .frame(width: rect.width * 0.18)
            .rotationEffect(.degrees(rotation))
            .position(point)
    }

    private func selection(at location: CGPoint, in rect: CGRect) -> EmotionSelection? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let normalizedRadius = radius / (rect.width / 2)

        guard normalizedRadius <= 1 else {
            return nil
        }

        var degrees = atan2(dy, dx) * 180 / .pi
        degrees = normalizedDegrees(degrees - wheelStart)

        let coreIndex = min(Int(degrees / 45), EmotionTaxonomy.cores.count - 1)
        let core = EmotionTaxonomy.cores[coreIndex]
        let coreOffset = degrees - Double(coreIndex) * 45

        if normalizedRadius <= innerOuter {
            return EmotionSelection(core: core, secondary: nil, specific: nil)
        }

        let secondaryIndex = min(Int(coreOffset / 11.25), core.secondaries.count - 1)
        let secondary = core.secondaries[secondaryIndex]

        if normalizedRadius <= middleOuter {
            return EmotionSelection(core: core, secondary: secondary, specific: nil)
        }

        let secondaryOffset = coreOffset - Double(secondaryIndex) * 11.25
        let specificIndex = min(Int(secondaryOffset / 3.75), secondary.specifics.count - 1)
        let specific = secondary.specifics[specificIndex]

        return EmotionSelection(core: core, secondary: secondary, specific: specific)
    }

    private func angles(for selection: EmotionSelection) -> (start: Double, end: Double) {
        guard let coreIndex = EmotionTaxonomy.cores.firstIndex(where: { $0.id == selection.core.id }) else {
            return (wheelStart, wheelStart)
        }

        let coreStart = wheelStart + Double(coreIndex) * 45

        guard let secondary = selection.secondary,
              let secondaryIndex = selection.core.secondaries.firstIndex(where: { $0.id == secondary.id }) else {
            return (coreStart, coreStart + 45)
        }

        let secondaryStart = coreStart + Double(secondaryIndex) * 11.25

        guard let specific = selection.specific,
              let specificIndex = secondary.specifics.firstIndex(where: { $0.id == specific.id }) else {
            return (secondaryStart, secondaryStart + 11.25)
        }

        let specificStart = secondaryStart + Double(specificIndex) * 3.75
        return (specificStart, specificStart + 3.75)
    }

    private func point(angle: Double, radiusRatio: CGFloat, rect: CGRect) -> CGPoint {
        let radians = angle * .pi / 180
        let radius = rect.width * radiusRatio / 2
        return CGPoint(
            x: rect.midX + cos(radians) * radius,
            y: rect.midY + sin(radians) * radius
        )
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }
}

private struct AnnularSegment: Shape {
    let startAngle: Double
    let endAngle: Double
    let innerRatio: CGFloat
    let outerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = side * outerRatio / 2
        let innerRadius = side * innerRatio / 2

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )

        if innerRadius == 0 {
            path.addLine(to: center)
        } else {
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: .degrees(endAngle),
                endAngle: .degrees(startAngle),
                clockwise: true
            )
        }

        path.closeSubpath()
        return path
    }
}
