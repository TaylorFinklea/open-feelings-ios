import SwiftUI
import SwiftData

struct ValuesArea: View {
    @Query(sort: \ValueSort.createdAt, order: .reverse) private var sorts: [ValueSort]
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @Query(sort: \CommittedAction.createdAt, order: .reverse) private var actions: [CommittedAction]
    @State private var showingSort = false
    @State private var showingEditor = false
    @State private var showingPastSorts = false
    @State private var showingCustomValues = false
    @State private var justFinishedSort: ValueSort?
    @State private var detail: ValueDetail?

    private var activeSort: ValueSort? { sorts.first }

    /// `sorts` is sorted newest-first; the prior of `target` is the row
    /// immediately *after* it in that array.
    private func priorOf(_ target: ValueSort) -> ValueSort? {
        guard let idx = sorts.firstIndex(where: { $0.id == target.id }),
              idx + 1 < sorts.count else { return nil }
        return sorts[idx + 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Values")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.OF.text)

            if let active = activeSort {
                populatedState(active: active)
            } else {
                EmptyStateCard { showingSort = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingSort) {
            SortFlowView { saved in
                justFinishedSort = saved
            }
        }
        .sheet(item: $justFinishedSort) { saved in
            SortComparisonView(
                current: saved,
                prior: priorOf(saved),
                onViewAllPastSorts: { showingPastSorts = true }
            )
        }
        .sheet(isPresented: $showingEditor) {
            if let active = activeSort {
                CommittedActionEditor(rankedTop: active.rankedTop, customs: customs)
            }
        }
        .sheet(item: $detail) { selected in
            ValueDetailSheet(ref: selected.ref, customs: customs)
        }
        .sheet(isPresented: $showingPastSorts) {
            PastSortsSheet()
        }
        .sheet(isPresented: $showingCustomValues) {
            CustomValuesSheet()
        }
    }

    @ViewBuilder
    private func populatedState(active: ValueSort) -> some View {
        HStack(spacing: CGFloat.OF.sm) {
            Text("YOUR VALUES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Spacer()
            if sorts.count > 1 {
                Button {
                    showingPastSorts = true
                } label: {
                    Label("Past sorts", systemImage: "clock.arrow.circlepath")
                }
                .font(.subheadline)
                .accessibilityIdentifier("values.past-sorts")
            }
            Button {
                showingSort = true
            } label: {
                Label("Re-sort", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.subheadline)
        }

        ForEach(Array(active.rankedTop.enumerated()), id: \.offset) { pair in
            Button {
                detail = ValueDetail(ref: pair.element)
            } label: {
                HStack {
                    Text("\(pair.offset + 1)")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 24, alignment: .leading)
                        .foregroundStyle(Color.OF.textMuted)
                    Text(ValueRef.displayName(for: pair.element, customs: customs))
                        .foregroundStyle(Color.OF.text)
                    Spacer()
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.OF.textMuted)
                }
                .padding(.vertical, .OF.xs)
                .padding(.horizontal, .OF.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .fill(Color.OF.surface)
                )
            }
            .buttonStyle(.plain)
        }

        HStack {
            Text("COMMITTED ACTIONS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Spacer()
            Button { showingEditor = true } label: {
                Image(systemName: "plus")
            }
        }
        .padding(.top, .OF.sm)

        if actions.isEmpty {
            Text("No committed actions yet. Tap + to add one.")
                .foregroundStyle(Color.OF.textMuted)
                .padding(.vertical, .OF.sm)
        } else {
            ForEach(actions) { action in
                NavigationLink {
                    CommittedActionDetail(action: action, customs: customs)
                } label: {
                    CommittedActionRow(action: action,
                                       customs: customs,
                                       activeRanked: active.rankedTop)
                }
                .buttonStyle(.plain)
            }
        }

        if !customs.isEmpty {
            Button {
                showingCustomValues = true
            } label: {
                Label("Manage custom values", systemImage: "slider.horizontal.3")
                    .font(.subheadline)
                    .foregroundStyle(Color.OF.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, .OF.sm)
            .accessibilityIdentifier("values.manage-custom")
        }
    }
}

private struct ValueDetail: Identifiable {
    let ref: String
    var id: String { ref }
}

private struct ValueDetailSheet: View {
    let ref: String
    let customs: [CustomValue]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: .OF.md) {
                Text(ValueRef.displayName(for: ref, customs: customs))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.OF.text)
                if !ValueRef.isCustom(ref), let def = ValueTaxonomy.definition(id: ref) {
                    Text(def.description)
                        .font(.body)
                        .foregroundStyle(Color.OF.textMuted)
                } else if ValueRef.isCustom(ref) {
                    Text("Your custom value.")
                        .font(.body)
                        .foregroundStyle(Color.OF.textMuted)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.OF.lg)
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct EmptyStateCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Your values, on your terms")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Text("A short card sort to figure out what matters to you, then a place to act on it.")
                .foregroundStyle(Color.OF.textMuted)
            Button(action: onStart) {
                Text("Start the sort")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, .OF.xs)
        }
        .padding(.OF.md)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }
}
