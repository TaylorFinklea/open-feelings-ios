import SwiftData
import SwiftUI

struct DirectionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                IntentionsContent()
                ValuesAreaPlaceholder()
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

/// Placeholder filled in by Task 8.
private struct ValuesAreaPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Values")
                .font(.title3.weight(.semibold))
            Text("Coming next.")
                .foregroundStyle(Color.OF.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack { DirectionView() }
        .modelContainer(for: [FeelingLog.self, Intention.self], inMemory: true)
}
