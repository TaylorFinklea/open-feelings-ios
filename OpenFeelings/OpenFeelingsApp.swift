import SwiftData
import SwiftUI

@main
struct OpenFeelingsApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var healthService = HealthService()
    @State private var navigation = AppNavigation()
    @State private var watchSyncService: WatchSyncService?
    @State private var cloudSyncMonitor = CloudSyncMonitor()
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            LockGateView {
                Group {
                    if let modelContainer {
                        RootView()
                            .modelContainer(modelContainer)
                    } else {
                        // Container not yet built. The lock screen lives outside
                        // this closure (only `content()` invokes it) so this branch
                        // only matters if a user unlocks before the deferred init
                        // completes, which is rare and brief on real devices.
                        Rectangle().fill(Color.OF.background).ignoresSafeArea()
                    }
                }
            }
            .preferredColorScheme(appearanceMode.colorScheme)
            .environment(healthService)
            .environment(navigation)
            .environment(watchSyncService)
            .environment(cloudSyncMonitor)
            .task {
                // Activate WatchConnectivity early so transferUserInfo payloads
                // queued before the SwiftData container is ready get buffered
                // rather than dropped.
                if watchSyncService == nil {
                    watchSyncService = WatchSyncService(healthService: healthService)
                }
                // Defer SwiftData container init until after the first frame so
                // the lock screen renders without waiting on store/CloudKit setup.
                // .task fires after onAppear, on @MainActor.
                if modelContainer == nil {
                    let container = OpenFeelingsModelContainer.shared
                    modelContainer = container
                    watchSyncService?.attach(modelContainer: container)
                }
            }
        }
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }
}
