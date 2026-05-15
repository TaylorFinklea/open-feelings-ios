import SwiftUI
import SwiftData

struct ValuesArea: View {
    @Query(sort: \ValueSort.createdAt, order: .reverse) private var sorts: [ValueSort]
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @Query(sort: \CommittedAction.createdAt, order: .reverse) private var actions: [CommittedAction]
    @State private var showingSort = false
    @State private var showingEditor = false

    private var activeSort: ValueSort? { sorts.first }

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
        .sheet(isPresented: $showingSort) { SortFlowView() }
        .sheet(isPresented: $showingEditor) {
            if let active = activeSort {
                CommittedActionEditor(rankedTop: active.rankedTop, customs: customs)
            }
        }
    }

    @ViewBuilder
    private func populatedState(active: ValueSort) -> some View {
        HStack {
            Text("YOUR VALUES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Spacer()
            Button {
                showingSort = true
            } label: {
                Label("Re-sort", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.subheadline)
        }

        ForEach(Array(active.rankedTop.enumerated()), id: \.offset) { pair in
            HStack {
                Text("\(pair.offset + 1)")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 24, alignment: .leading)
                    .foregroundStyle(Color.OF.textMuted)
                Text(ValueRef.displayName(for: pair.element, customs: customs))
                    .foregroundStyle(Color.OF.text)
            }
            .padding(.vertical, .OF.xs)
            .padding(.horizontal, .OF.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                    .fill(Color.OF.surface)
            )
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
