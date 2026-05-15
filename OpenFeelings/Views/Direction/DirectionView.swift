import SwiftData
import SwiftUI

struct DirectionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                IntentionsContent()
                ValuesArea()
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Direction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { DirectionView() }
        .modelContainer(for: [FeelingLog.self, Intention.self], inMemory: true)
}
