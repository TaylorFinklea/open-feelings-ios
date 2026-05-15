import SwiftUI

struct DirectionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Values")
                .font(.title3.weight(.semibold))
            Text("Coming next.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack { DirectionView() }
}
