import SwiftUI
import SwiftData

struct ValuesArea: View {
    @Query(sort: \ValueSort.createdAt, order: .reverse) private var sorts: [ValueSort]
    @State private var showingSort = false

    private var activeSort: ValueSort? { sorts.first }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Values")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.OF.text)

            if activeSort == nil {
                EmptyStateCard { showingSort = true }
            } else {
                Text("Sort exists — populated state lands in Task 11.")
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingSort) {
            // Placeholder — SortFlowView lands in Task 10.
            Text("Sort flow — Task 10")
                .padding()
                .presentationDetents([.medium])
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
