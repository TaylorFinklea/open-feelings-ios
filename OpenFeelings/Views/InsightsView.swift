import SwiftUI

struct InsightsView: View {
    var body: some View {
        VStack {
            Text("Insights (placeholder)").foregroundStyle(Color.OF.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.OF.background)
        .ignoresSafeArea()
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { InsightsView() } }
