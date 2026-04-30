import SwiftUI

struct IntentionsView: View {
    var body: some View {
        VStack {
            Text("Intentions (placeholder)").foregroundStyle(Color.OF.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.OF.background)
        .ignoresSafeArea()
        .navigationTitle("Intentions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { IntentionsView() } }
