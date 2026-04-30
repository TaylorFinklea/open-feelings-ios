import SwiftUI

struct WheelCheckInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: EmotionSelection?

    private var selectionDepth: EmotionColorPalette.Depth {
        if selection?.specific != nil { return .specific }
        if selection?.secondary != nil { return .secondary }
        return .core
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            Text("Tap the wheel")
                .font(.OF.headline)
                .foregroundStyle(Color.OF.text)

            EmotionWheelView(selection: $selection)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel("Emotion wheel")

            if let selection {
                Text(selection.pathTitle)
                    .font(.OF.bodyEmphasis)
                    .foregroundStyle(Color.readableText(onHex: EmotionColorPalette.hexString(coreID: selection.core.id, depth: selectionDepth, scheme: colorScheme)))
                    .lineLimit(2)
                    .padding(.horizontal, CGFloat.OF.md)
                    .padding(.vertical, CGFloat.OF.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        EmotionColorPalette.color(coreID: selection.core.id, depth: selectionDepth, scheme: colorScheme),
                        in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
                    )
            }

            Text("Tap the center for a broad feeling, the middle ring to narrow it, or the outer ring for the exact word.")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
        }
    }
}

struct EmotionWheelView: View {
    @Binding var selection: EmotionSelection?

    @Environment(\.colorScheme) private var colorScheme

    @State private var baseScale: CGFloat = 1
    @State private var baseRotation = 0.0
    @State private var baseOffset: CGSize = .zero

    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureRotation: Angle = .zero
    @GestureState private var gestureOffset: CGSize = .zero

    private let innerOuter: CGFloat = 0.28
    private let middleOuter: CGFloat = 0.58
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
            let layout = EmotionWheelLayout(cores: EmotionTaxonomy.cores)
            let transform = activeTransform(side: side)

            ZStack {
                wheelContent(layout: layout, rect: rect)
                    .scaleEffect(transform.scale)
                    .rotationEffect(.degrees(transform.rotationDegrees))
                    .offset(transform.offset)

                if !isAtRest {
                    resetButton
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(tapGesture(rect: rect, layout: layout, transform: transform))
            .simultaneousGesture(panGesture(side: side))
            .simultaneousGesture(zoomGesture(side: side))
            .simultaneousGesture(rotationGesture)
            .accessibilityHint("Pinch to zoom, rotate with two fingers, drag while zoomed, or use the reset button to restore the wheel.")
        }
    }

    private func wheelContent(layout: EmotionWheelLayout, rect: CGRect) -> some View {
        ZStack {
            ForEach(layout.cores) { coreSlice in
                coreSegments(coreSlice, rect: rect)
            }

            ringLines(rect: rect)
            selectionRing(layout: layout, rect: rect)
        }
        .drawingGroup()
    }

    private var resetButton: some View {
        Button {
            resetTransform()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .tint(.black.opacity(0.56))
        .accessibilityLabel("Reset wheel view")
    }

    private var isAtRest: Bool {
        abs(baseScale - 1) < 0.01
            && abs(baseRotation) < 0.01
            && abs(baseOffset.width) < 0.5
            && abs(baseOffset.height) < 0.5
    }

    private func activeTransform(side: CGFloat) -> WheelViewportTransform {
        let scale = WheelViewportTransform.clampedScale(baseScale * gestureScale)
        let proposedOffset = CGSize(
            width: baseOffset.width + gestureOffset.width,
            height: baseOffset.height + gestureOffset.height
        )

        return WheelViewportTransform(
            scale: scale,
            rotationDegrees: normalizedDegrees(baseRotation + gestureRotation.degrees),
            offset: WheelViewportTransform.clampedOffset(proposedOffset, scale: scale, side: side)
        )
    }

    private func resetTransform() {
        withAnimation(.snappy(duration: 0.22)) {
            baseScale = 1
            baseRotation = 0
            baseOffset = .zero
        }
    }

    private func tapGesture(
        rect: CGRect,
        layout: EmotionWheelLayout,
        transform: WheelViewportTransform
    ) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let wheelPoint = transform.inverted(value.location, around: CGPoint(x: rect.midX, y: rect.midY))
                selection = selection(at: wheelPoint, in: rect, layout: layout)
            }
    }

    private func panGesture(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($gestureOffset) { value, state, _ in
                guard baseScale > 1.01 else {
                    return
                }

                state = value.translation
            }
            .onEnded { value in
                guard baseScale > 1.01 else {
                    baseOffset = .zero
                    return
                }

                let proposedOffset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
                baseOffset = WheelViewportTransform.clampedOffset(proposedOffset, scale: baseScale, side: side)
            }
    }

    private func zoomGesture(side: CGFloat) -> some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                baseScale = WheelViewportTransform.clampedScale(baseScale * value)
                baseOffset = WheelViewportTransform.clampedOffset(baseOffset, scale: baseScale, side: side)
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($gestureRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                baseRotation = normalizedDegrees(baseRotation + value.degrees)
            }
    }

    @ViewBuilder
    private func coreSegments(_ coreSlice: CoreSlice, rect: CGRect) -> some View {
        let core = coreSlice.core

        AnnularSegment(
            startAngle: wheelStart + coreSlice.start,
            endAngle: wheelStart + coreSlice.end,
            innerRatio: 0,
            outerRatio: innerOuter
        )
        .fill(EmotionColorPalette.color(coreID: core.id, depth: .core, scheme: colorScheme))

        wheelLabel(
            core.name,
            colorHex: EmotionColorPalette.hexString(coreID: core.id, depth: .core, scheme: colorScheme),
            angle: wheelStart + coreSlice.midAngle,
            radiusRatio: innerOuter * 0.62,
            rect: rect,
            ringWidthRatio: innerOuter,
            size: 11,
            weight: .semibold
        )

        ForEach(coreSlice.secondaries) { secondarySlice in
            let secondary = secondarySlice.secondary

            AnnularSegment(
                startAngle: wheelStart + secondarySlice.start,
                endAngle: wheelStart + secondarySlice.end,
                innerRatio: innerOuter,
                outerRatio: middleOuter
            )
            .fill(EmotionColorPalette.color(coreID: core.id, depth: .secondary, scheme: colorScheme))

            wheelLabel(
                secondary.name,
                colorHex: EmotionColorPalette.hexString(coreID: core.id, depth: .secondary, scheme: colorScheme),
                angle: wheelStart + secondarySlice.midAngle,
                radiusRatio: (innerOuter + middleOuter) / 2,
                rect: rect,
                ringWidthRatio: middleOuter - innerOuter,
                size: 7.4,
                weight: .medium
            )

            ForEach(secondarySlice.specifics) { specificSlice in
                let specific = specificSlice.specific

                AnnularSegment(
                    startAngle: wheelStart + specificSlice.start,
                    endAngle: wheelStart + specificSlice.end,
                    innerRatio: middleOuter,
                    outerRatio: 1
                )
                .fill(EmotionColorPalette.color(coreID: core.id, depth: .specific, scheme: colorScheme))

                wheelLabel(
                    specific.name,
                    colorHex: EmotionColorPalette.hexString(coreID: core.id, depth: .specific, scheme: colorScheme),
                    angle: wheelStart + specificSlice.midAngle,
                    radiusRatio: (middleOuter + 1) / 2,
                    rect: rect,
                    ringWidthRatio: 1 - middleOuter,
                    size: 5.8,
                    weight: .regular
                )
            }
        }
    }

    @ViewBuilder
    private func ringLines(rect: CGRect) -> some View {
        Circle()
            .stroke(.primary.opacity(0.22), lineWidth: 0.8)
            .frame(width: rect.width * innerOuter, height: rect.height * innerOuter)
            .position(x: rect.midX, y: rect.midY)

        Circle()
            .stroke(.primary.opacity(0.22), lineWidth: 0.8)
            .frame(width: rect.width * middleOuter, height: rect.height * middleOuter)
            .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private func selectionRing(layout: EmotionWheelLayout, rect: CGRect) -> some View {
        if let selection,
           let angles = layout.angles(for: selection) {
            let ratios: (inner: CGFloat, outer: CGFloat) = if selection.specific != nil {
                (middleOuter, 1)
            } else if selection.secondary != nil {
                (innerOuter, middleOuter)
            } else {
                (0, innerOuter)
            }

            AnnularSegment(
                startAngle: wheelStart + angles.start,
                endAngle: wheelStart + angles.end,
                innerRatio: ratios.inner,
                outerRatio: ratios.outer
            )
            .stroke(.white, lineWidth: 3)
            .shadow(color: .black.opacity(0.5), radius: 2)
        }
    }

    private func wheelLabel(
        _ text: String,
        colorHex: String,
        angle: Double,
        radiusRatio: CGFloat,
        rect: CGRect,
        ringWidthRatio: CGFloat,
        size: CGFloat,
        weight: Font.Weight
    ) -> some View {
        let point = point(angle: angle, radiusRatio: radiusRatio, rect: rect)
        let normalized = normalizedDegrees(angle)
        let rotation = normalized > 90 && normalized < 270 ? angle + 180 : angle
        let labelWidth = rect.width * ringWidthRatio * 0.46

        return Text(text)
            .font(.system(size: size, weight: weight))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .foregroundStyle(Color.readableText(onHex: colorHex))
            .shadow(color: .black.opacity(0.22), radius: 0.8)
            .frame(width: labelWidth, height: size + 4)
            .rotationEffect(.degrees(rotation))
            .position(point)
            .accessibilityHidden(true)
    }

    private func selection(at location: CGPoint, in rect: CGRect, layout: EmotionWheelLayout) -> EmotionSelection? {
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

        guard let coreSlice = layout.core(at: degrees) else {
            return nil
        }

        if normalizedRadius <= innerOuter {
            return EmotionSelection(core: coreSlice.core, secondary: nil, specific: nil)
        }

        guard let secondarySlice = coreSlice.secondary(at: degrees) else {
            return EmotionSelection(core: coreSlice.core, secondary: nil, specific: nil)
        }

        if normalizedRadius <= middleOuter {
            return EmotionSelection(core: coreSlice.core, secondary: secondarySlice.secondary, specific: nil)
        }

        let specific = secondarySlice.specific(at: degrees)?.specific
        return EmotionSelection(
            core: coreSlice.core,
            secondary: secondarySlice.secondary,
            specific: specific
        )
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

struct WheelViewportTransform: Equatable {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 4

    let scale: CGFloat
    let rotationDegrees: Double
    let offset: CGSize

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }

    static func clampedOffset(_ offset: CGSize, scale: CGFloat, side: CGFloat) -> CGSize {
        let limit = max((side * (scale - minimumScale)) / 2, 0)

        guard limit > 0 else {
            return .zero
        }

        return CGSize(
            width: min(max(offset.width, -limit), limit),
            height: min(max(offset.height, -limit), limit)
        )
    }

    func applied(_ point: CGPoint, around center: CGPoint) -> CGPoint {
        let radians = CGFloat(rotationDegrees * .pi / 180)
        let translatedX = (point.x - center.x) * scale
        let translatedY = (point.y - center.y) * scale

        let rotatedX = translatedX * cos(radians) - translatedY * sin(radians)
        let rotatedY = translatedX * sin(radians) + translatedY * cos(radians)

        return CGPoint(
            x: center.x + rotatedX + offset.width,
            y: center.y + rotatedY + offset.height
        )
    }

    func inverted(_ point: CGPoint, around center: CGPoint) -> CGPoint {
        let radians = CGFloat(-rotationDegrees * .pi / 180)
        let translatedX = point.x - center.x - offset.width
        let translatedY = point.y - center.y - offset.height

        let rotatedX = translatedX * cos(radians) - translatedY * sin(radians)
        let rotatedY = translatedX * sin(radians) + translatedY * cos(radians)

        return CGPoint(
            x: center.x + rotatedX / scale,
            y: center.y + rotatedY / scale
        )
    }
}

private struct EmotionWheelLayout {
    let cores: [CoreSlice]

    init(cores source: [EmotionCore]) {
        let totalLeaves = Double(max(source.reduce(0) { $0 + $1.leafCount }, 1))
        var currentCoreStart = 0.0
        var coreSlices: [CoreSlice] = []

        for core in source {
            let coreWeight = Double(max(core.leafCount, 1))
            let coreEnd = currentCoreStart + (360 * coreWeight / totalLeaves)
            var currentSecondaryStart = currentCoreStart
            var secondarySlices: [SecondarySlice] = []

            for secondary in core.secondaries {
                let secondaryWeight = Double(max(secondary.leafCount, 1))
                let secondaryEnd = currentSecondaryStart + ((coreEnd - currentCoreStart) * secondaryWeight / coreWeight)
                var currentSpecificStart = currentSecondaryStart
                var specificSlices: [SpecificSlice] = []

                for specific in secondary.specifics {
                    let specificEnd = currentSpecificStart + ((secondaryEnd - currentSecondaryStart) / Double(max(secondary.specifics.count, 1)))
                    specificSlices.append(SpecificSlice(
                        specific: specific,
                        start: currentSpecificStart,
                        end: specificEnd
                    ))
                    currentSpecificStart = specificEnd
                }

                secondarySlices.append(SecondarySlice(
                    secondary: secondary,
                    start: currentSecondaryStart,
                    end: secondaryEnd,
                    specifics: specificSlices
                ))
                currentSecondaryStart = secondaryEnd
            }

            coreSlices.append(CoreSlice(
                core: core,
                start: currentCoreStart,
                end: coreEnd,
                secondaries: secondarySlices
            ))
            currentCoreStart = coreEnd
        }

        cores = coreSlices
    }

    func core(at angle: Double) -> CoreSlice? {
        cores.first { $0.contains(angle) } ?? cores.last
    }

    func angles(for selection: EmotionSelection) -> (start: Double, end: Double)? {
        guard let coreSlice = cores.first(where: { $0.core.id == selection.core.id }) else {
            return nil
        }

        guard let secondary = selection.secondary else {
            return (coreSlice.start, coreSlice.end)
        }

        guard let secondarySlice = coreSlice.secondaries.first(where: { $0.secondary.id == secondary.id }) else {
            return (coreSlice.start, coreSlice.end)
        }

        guard let specific = selection.specific else {
            return (secondarySlice.start, secondarySlice.end)
        }

        guard let specificSlice = secondarySlice.specifics.first(where: { $0.specific.id == specific.id }) else {
            return (secondarySlice.start, secondarySlice.end)
        }

        return (specificSlice.start, specificSlice.end)
    }
}

private struct CoreSlice: Identifiable {
    var id: String { core.id }

    let core: EmotionCore
    let start: Double
    let end: Double
    let secondaries: [SecondarySlice]

    var midAngle: Double { (start + end) / 2 }

    func contains(_ angle: Double) -> Bool {
        angle >= start && (angle < end || (end >= 360 && angle <= 360))
    }

    func secondary(at angle: Double) -> SecondarySlice? {
        secondaries.first { $0.contains(angle) } ?? secondaries.last
    }
}

private struct SecondarySlice: Identifiable {
    var id: String { secondary.id }

    let secondary: EmotionSecondary
    let start: Double
    let end: Double
    let specifics: [SpecificSlice]

    var midAngle: Double { (start + end) / 2 }

    func contains(_ angle: Double) -> Bool {
        angle >= start && (angle < end || (end >= 360 && angle <= 360))
    }

    func specific(at angle: Double) -> SpecificSlice? {
        specifics.first { $0.contains(angle) } ?? specifics.last
    }
}

private struct SpecificSlice: Identifiable {
    var id: String { specific.id }

    let specific: EmotionSpecific
    let start: Double
    let end: Double

    var midAngle: Double { (start + end) / 2 }

    func contains(_ angle: Double) -> Bool {
        angle >= start && (angle < end || (end >= 360 && angle <= 360))
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
