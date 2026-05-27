import SwiftUI
import SwiftData

/// Hosts the four-screen sort flow. Owns the SortSession.
struct SortFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    /// Called after the user taps Confirm on the last step and the new
    /// `ValueSort` row is committed. The parent surface uses this to
    /// dismiss the sort sheet and present the auto-compare modal.
    var onCompleted: ((ValueSort) -> Void)? = nil

    @State private var session: SortSession?

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    switch session.phase {
                    case .bucketing:        SwipeBucketStepView(session: session)
                    case .pickingFinalists: FinalistsStepView(session: session)
                    case .ranking:          RankStepView(session: session)
                    case .confirming:       ConfirmSortView(session: session) { saved in
                        onCompleted?(saved)
                        dismiss()
                    }
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            if session == nil {
                session = SortSession(curated: ValueTaxonomy.all, custom: customs)
            }
        }
    }
}
