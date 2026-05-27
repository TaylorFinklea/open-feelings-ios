import SwiftData
import SwiftUI

/// Modal that auto-appears after a re-sort saves. Shows side-by-side
/// prior vs new ranked-top-5 with deltas highlighted inline (added in
/// green, removed in muted red strike-through, moved as accent chips
/// below the new column). Two actions: Done, and View all past sorts
/// (which opens the full PastSortsSheet).
struct SortComparisonView: View {
    let current: ValueSort
    let prior: ValueSort?
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @Environment(\.dismiss) private var dismiss

    var onViewAllPastSorts: () -> Void

    private var delta: SortDelta {
        SortDelta.compute(prior: prior?.rankedTop, current: current.rankedTop)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
                    if prior == nil {
                        firstSortMessage
                    } else {
                        comparisonGrid
                        if !delta.moved.isEmpty {
                            movedSection
                        }
                    }

                    actions
                }
                .padding(CGFloat.OF.md)
            }
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
            .navigationTitle("What changed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("sort-comparison.done")
                }
            }
        }
    }

    @ViewBuilder
    private var firstSortMessage: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("Your first sort")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.OF.text)
            Text("Once you sort again, this view will show what shifted.")
                .foregroundStyle(Color.OF.textMuted)
            rankedColumn(title: nil, refs: Array(current.rankedTop.prefix(5)),
                         additions: Set(current.rankedTop), removals: Set())
        }
    }

    @ViewBuilder
    private var comparisonGrid: some View {
        HStack(alignment: .top, spacing: CGFloat.OF.md) {
            rankedColumn(
                title: current.createdAt.formatted(date: .abbreviated, time: .omitted),
                refs: Array(current.rankedTop.prefix(5)),
                additions: Set(delta.added),
                removals: Set()
            )
            if let prior {
                rankedColumn(
                    title: prior.createdAt.formatted(date: .abbreviated, time: .omitted),
                    refs: Array(prior.rankedTop.prefix(5)),
                    additions: Set(),
                    removals: Set(delta.removed)
                )
            }
        }
    }

    @ViewBuilder
    private func rankedColumn(title: String?, refs: [String],
                              additions: Set<String>, removals: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.OF.textMuted)
                    .tracking(0.8)
            }
            ForEach(Array(refs.enumerated()), id: \.offset) { idx, ref in
                let name = ValueRef.displayName(for: ref, customs: customs)
                Text("\(idx + 1). \(name)")
                    .font(.body)
                    .foregroundStyle(rowColor(ref: ref,
                                              additions: additions,
                                              removals: removals))
                    .strikethrough(removals.contains(ref))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CGFloat.OF.md)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }

    private func rowColor(ref: String,
                          additions: Set<String>,
                          removals: Set<String>) -> AnyShapeStyle {
        if removals.contains(ref) { return AnyShapeStyle(Color.OF.textMuted) }
        if additions.contains(ref) { return AnyShapeStyle(Color.green) }
        return AnyShapeStyle(Color.OF.text)
    }

    @ViewBuilder
    private var movedSection: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            Text("MOVED")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.OF.textMuted)
                .tracking(0.8)
            ForEach(delta.moved, id: \.ref) { move in
                let name = ValueRef.displayName(for: move.ref, customs: customs)
                HStack(spacing: CGFloat.OF.xs) {
                    Text(name)
                        .foregroundStyle(Color.OF.text)
                    Text("\(move.from + 1) → \(move.to + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.OF.accent)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(CGFloat.OF.md)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }

    @ViewBuilder
    private var actions: some View {
        if prior != nil {
            Button {
                dismiss()
                onViewAllPastSorts()
            } label: {
                Text("View all past sorts")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("sort-comparison.view-all")
        }
    }
}
