// OpenFeelings/Design/Components/OFChip.swift
import SwiftUI

/// A small toggleable pill used in chip-row pickers (body region, sensation,
/// future tag pickers). Token-driven: warm-calm tokens for fill, stroke, and
/// type. Selected state uses accent fill + textOnAccent foreground; unselected
/// is a surface fill with a divider stroke and primary text.
struct OFChip: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.OF.quick) { isOn.toggle() }
        } label: {
            Text(label)
                .font(.OF.caption.weight(.semibold))
                .foregroundStyle(isOn ? Color.OF.textOnAccent : Color.OF.text)
                .padding(.horizontal, CGFloat.OF.md)
                .padding(.vertical, CGFloat.OF.sm)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn ? AnyShapeStyle(Color.OF.accent) : AnyShapeStyle(Color.OF.surface))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isOn ? Color.OF.accent : Color.OF.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(Self.identifier(for: label))
    }

    nonisolated static func identifier(for label: String) -> String {
        var output = ""
        var lastWasSeparator = true

        for character in label.lowercased() {
            if character.isLetter || character.isNumber {
                output.append(character)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                output.append("-")
                lastWasSeparator = true
            }
        }

        while output.hasSuffix("-") {
            output.removeLast()
        }

        return "chip.\(output)"
    }
}

/// Lays out subviews left-to-right, wrapping to a new line when the next
/// subview would overflow the proposed width. Spacing between items and
/// between rows is configurable. Used for chip rows in CheckIn body picker.
struct WrapLayout: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let maxWidth = proposal.width else {
            return idealUnboundedSize(subviews)
        }
        let rows = layoutRows(maxWidth: maxWidth, subviews: subviews)
        let totalHeight = rows.reduce(into: CGFloat(0)) { acc, row in
            acc += row.height
        } + (rows.isEmpty ? 0 : CGFloat(rows.count - 1) * vSpacing)
        let widestRow = rows.map(\.width).max() ?? 0
        return CGSize(width: widestRow, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let rows = layoutRows(maxWidth: maxWidth, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indexes {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + hSpacing
            }
            y += row.height + vSpacing
        }
    }

    private struct Row {
        var indexes: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indexes.isEmpty ? size.width : current.width + hSpacing + size.width
            if needed > maxWidth, !current.indexes.isEmpty {
                rows.append(current)
                current = Row()
            }
            if current.indexes.isEmpty {
                current.indexes = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indexes.append(index)
                current.width += hSpacing + size.width
                current.height = max(current.height, size.height)
            }
        }
        if !current.indexes.isEmpty { rows.append(current) }
        return rows
    }

    private func idealUnboundedSize(_ subviews: Subviews) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let totalW = sizes.reduce(into: CGFloat(0)) { $0 += $1.width }
        let spacingW = sizes.isEmpty ? 0 : CGFloat(sizes.count - 1) * hSpacing
        let maxH = sizes.map(\.height).max() ?? 0
        return CGSize(width: totalW + spacingW, height: maxH)
    }
}

#Preview {
    struct Demo: View {
        @State private var picks: Set<String> = ["chest"]
        let regions = ["head", "throat", "chest", "stomach", "gut", "shoulders", "back", "hands", "legs", "whole body"]

        var body: some View {
            ScrollView {
                WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                    ForEach(regions, id: \.self) { region in
                        OFChip(label: region.capitalized, isOn: bind(region))
                    }
                }
                .padding(CGFloat.OF.lg)
            }
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        }

        private func bind(_ key: String) -> Binding<Bool> {
            Binding(
                get: { picks.contains(key) },
                set: { isOn in
                    if isOn { picks.insert(key) } else { picks.remove(key) }
                }
            )
        }
    }
    return Demo()
}
