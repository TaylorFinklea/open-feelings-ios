import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CheckInView()
            }
            .tabItem {
                Label("Check In", systemImage: "circle.grid.3x3")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    RootView()
        .environment(HealthService())
}
