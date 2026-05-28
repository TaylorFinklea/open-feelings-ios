import SwiftData
import SwiftUI

/// Top-level Thoughts tab. Hosts the CBT thought-record list + wizard,
/// split out of the Direction tab to keep Direction focused on values
/// and intentions. Mirrors `DirectionView`'s structure.
struct ThoughtsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                ThoughtRecordsArea()
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Thoughts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ThoughtsView() }
        .modelContainer(for: [ThoughtRecord.self, FeelingLog.self], inMemory: true)
}
