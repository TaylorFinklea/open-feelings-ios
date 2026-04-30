import SwiftUI

struct TodayView: View {
    var body: some View {
        VStack {
            Text("Today (placeholder)").foregroundStyle(Color.OF.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.OF.background)
        .ignoresSafeArea()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { TodayView() } }
