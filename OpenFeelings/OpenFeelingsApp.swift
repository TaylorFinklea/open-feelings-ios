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
                    let container = OpenFeelingsApp.makeModelContainer()
                    modelContainer = container
                    watchSyncService?.attach(modelContainer: container)
                }
            }
        }
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self,
            ThoughtRecord.self
        ])

        #if DEBUG
        // Screenshot mode: an in-memory store seeded with curated demo data, so
        // App Store screenshots show populated screens without using real data.
        if CommandLine.arguments.contains("-screenshotMode") {
            let screenshotConfiguration = ModelConfiguration(
                "OpenFeelingsScreenshots",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [screenshotConfiguration])
                ScreenshotDemoSeeder.seed(into: container.mainContext)
                return container
            } catch {
                fatalError("Unable to create Open Feelings screenshot model container: \(error)")
            }
        }
        #endif

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testConfiguration = ModelConfiguration(
                "OpenFeelingsTests",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [testConfiguration])
            } catch {
                fatalError("Unable to create Open Feelings test model container: \(error)")
            }
        }

        #if targetEnvironment(simulator)
        let simulatorConfiguration = ModelConfiguration(
            "OpenFeelingsSimulator",
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [simulatorConfiguration])
        } catch {
            fatalError("Unable to create Open Feelings simulator model container: \(error)")
        }
        #else
        let cloudConfiguration = ModelConfiguration(
            "OpenFeelingsCloud",
            schema: schema,
            cloudKitDatabase: .private("iCloud.dev.finklea.openfeelings")
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            let localConfiguration = ModelConfiguration(
                "OpenFeelingsLocal",
                schema: schema,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Unable to create Open Feelings model container: \(error)")
            }
        }
        #endif
    }
}
