import SwiftUI

struct RootView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack(path: $navigation.todayPath) {
                TodayView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                    .accessibilityIdentifier("tab.today")
            }
            .tag(AppTab.today)

            NavigationStack {
                CheckInView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.systemImage)
                    .accessibilityIdentifier("tab.checkIn")
            }
            .tag(AppTab.checkIn)

            NavigationStack {
                DirectionView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.direction.title, systemImage: AppTab.direction.systemImage)
                    .accessibilityIdentifier("tab.direction")
            }
            .tag(AppTab.direction)

            NavigationStack {
                ThoughtsView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.thoughts.title, systemImage: AppTab.thoughts.systemImage)
                    .accessibilityIdentifier("tab.thoughts")
            }
            .tag(AppTab.thoughts)

            NavigationStack {
                InsightsView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.insights.title, systemImage: AppTab.insights.systemImage)
                    .accessibilityIdentifier("tab.insights")
            }
            .tag(AppTab.insights)
        }
        .sheet(isPresented: $navigation.showingSettings) {
            NavigationStack { SettingsView() }
        }
    }
}

#Preview {
    RootView()
        .environment(HealthService())
        .environment(AppNavigation())
}
