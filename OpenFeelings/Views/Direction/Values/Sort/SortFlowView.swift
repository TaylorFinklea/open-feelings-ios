import SwiftUI
import SwiftData

/// Hosts the four-screen sort flow. Owns the SortSession.
struct SortFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    @State private var session: SortSession?

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    switch session.phase {
                    case .bucketing:        BucketStepView(session: session)
                    case .pickingFinalists: FinalistsStepView(session: session)
                    case .ranking:          RankStepView(session: session)
                    case .confirming:       ConfirmSortView(session: session)
                    }
                } else {
                    ProgressView()
                }
            }
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
