import SwiftData
import SwiftUI

/// Modal list of every `ValueSort` newest-first. Each row shows date +
/// ranked top 5 names + a delta strip vs the immediately-prior sort.
/// Swipe-to-delete removes a sort; since the active sort is `sorts.first`
/// (newest), deleting the active sort automatically promotes the next.
/// Deleting a sort orphans nothing — `rankedTop` refs are internal to it.
struct PastSortsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ValueSort.createdAt, order: .reverse) private var sorts: [ValueSort]
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    @State private var pendingDelete: ValueSort?

    var body: some View {
        NavigationStack {
            Group {
                if sorts.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(Array(sorts.enumerated()), id: \.element.id) { idx, sort in
                            row(sort: sort, prior: prior(after: idx), isActive: idx == 0)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: CGFloat.OF.xs, leading: CGFloat.OF.md,
                                                          bottom: CGFloat.OF.xs, trailing: CGFloat.OF.md))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDelete = sort
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
            .navigationTitle("Past sorts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(item: $pendingDelete) { sort in
                Alert(
                    title: Text("Delete this sort?"),
                    message: Text("Removes the \(sort.createdAt.formatted(date: .abbreviated, time: .omitted)) sort from your history. You can re-sort anytime."),
                    primaryButton: .destructive(Text("Delete")) {
                        Self.delete(sort, in: context)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // MARK: - Mutations (static for testability)

    /// Delete the sort. `sorts` is newest-first, so deleting the active
    /// (newest) sort promotes the next-newest via `sorts.first` on the
    /// next render. No cascade.
    static func delete(_ sort: ValueSort, in context: ModelContext) {
        context.delete(sort)
        try? context.save()
    }

    /// `sorts` is newest-first. The prior sort of the row at index `idx`
    /// is the row at index `idx + 1` (older). Returns nil for the oldest.
    private func prior(after idx: Int) -> ValueSort? {
        let nextIdx = idx + 1
        guard nextIdx < sorts.count else { return nil }
        return sorts[nextIdx]
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("No sorts yet.")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Text("Complete a value sort to see your history here.")
                .font(.subheadline)
                .foregroundStyle(Color.OF.textMuted)
        }
        .padding(CGFloat.OF.lg)
    }

    @ViewBuilder
    private func row(sort: ValueSort, prior: ValueSort?, isActive: Bool) -> some View {
        let delta = SortDelta.compute(prior: prior?.rankedTop, current: sort.rankedTop)
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            HStack {
                Text(sort.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.OF.textMuted)
                if isActive {
                    Text("· Active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.OF.accent)
                }
                Spacer()
            }
            rankedList(refs: Array(sort.rankedTop.prefix(5)))
            if prior != nil {
                deltaStrip(delta)
            }
        }
        .padding(CGFloat.OF.md)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
        .accessibilityIdentifier("past-sorts.row.\(sort.id.uuidString)")
    }

    @ViewBuilder
    private func rankedList(refs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(refs.enumerated()), id: \.offset) { pair in
                HStack(spacing: CGFloat.OF.xs) {
                    Text("\(pair.offset + 1).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.OF.textMuted)
                        .frame(width: 20, alignment: .leading)
                    Text(ValueRef.displayName(for: pair.element, customs: customs))
                        .font(.body)
                        .foregroundStyle(Color.OF.text)
                }
            }
        }
    }

    @ViewBuilder
    private func deltaStrip(_ delta: SortDelta) -> some View {
        if delta.added.isEmpty && delta.removed.isEmpty && delta.moved.isEmpty {
            EmptyView()
        } else {
            FlowLayout(spacing: CGFloat.OF.xs) {
                ForEach(delta.added, id: \.self) { ref in
                    chip(text: "+ \(ValueRef.displayName(for: ref, customs: customs))",
                         style: .added)
                }
                ForEach(delta.removed, id: \.self) { ref in
                    chip(text: "− \(ValueRef.displayName(for: ref, customs: customs))",
                         style: .removed)
                }
                ForEach(delta.moved, id: \.ref) { move in
                    chip(text: "\(ValueRef.displayName(for: move.ref, customs: customs)) \(move.from + 1)→\(move.to + 1)",
                         style: .moved)
                }
            }
            .padding(.top, 2)
        }
    }

    private enum ChipStyle { case added, removed, moved }

    @ViewBuilder
    private func chip(text: String, style: ChipStyle) -> some View {
        let color: Color = {
            switch style {
            case .added:   return .green
            case .removed: return .red
            case .moved:   return Color.OF.accent.color(for: .dark)
            }
        }()
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, CGFloat.OF.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.18),
                        in: Capsule())
            .strikethrough(style == .removed)
    }
}

/// Minimal wrap-around horizontal layout for the delta chips. SwiftUI's
/// `HStack` doesn't wrap; using `Layout` is the lightweight modern path.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentY += rowHeight + spacing
                currentX = 0
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, currentX)
        }
        return CGSize(width: min(maxX, width), height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentY += rowHeight + spacing
                currentX = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
