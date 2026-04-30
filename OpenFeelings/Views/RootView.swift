import SwiftUI

struct RootView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack { TodayView() }
                .tabItem {
                    Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                }
                .tag(AppTab.today)

            NavigationStack { CheckInView() }
                .tabItem {
                    Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.systemImage)
                }
                .tag(AppTab.checkIn)

            NavigationStack { InsightsView() }
                .tabItem {
                    Label(AppTab.insights.title, systemImage: AppTab.insights.systemImage)
                }
                .tag(AppTab.insights)

            NavigationStack { IntentionsView() }
                .tabItem {
                    Label(AppTab.intentions.title, systemImage: AppTab.intentions.systemImage)
                }
                .tag(AppTab.intentions)

            NavigationStack { SettingsView() }
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
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
