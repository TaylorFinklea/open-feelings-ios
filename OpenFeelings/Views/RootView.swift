import SwiftUI

struct RootView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack(path: $navigation.todayPath) { TodayView() }
                .tabItem {
                    Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                        .accessibilityIdentifier("tab.today")
                }
                .tag(AppTab.today)

            NavigationStack { CheckInView() }
                .tabItem {
                    Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.systemImage)
                        .accessibilityIdentifier("tab.checkIn")
                }
                .tag(AppTab.checkIn)

            NavigationStack { InsightsView() }
                .tabItem {
                    Label(AppTab.insights.title, systemImage: AppTab.insights.systemImage)
                        .accessibilityIdentifier("tab.insights")
                }
                .tag(AppTab.insights)

            NavigationStack { IntentionsView() }
                .tabItem {
                    Label(AppTab.intentions.title, systemImage: AppTab.intentions.systemImage)
                        .accessibilityIdentifier("tab.intentions")
                }
                .tag(AppTab.intentions)

            NavigationStack { SettingsView() }
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                        .accessibilityIdentifier("tab.settings")
                }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    RootView()
        .environment(HealthService())
        .environment(AppNavigation())
}
