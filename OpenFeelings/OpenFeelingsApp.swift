import SwiftData
import SwiftUI

@main
struct OpenFeelingsApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var healthService = HealthService()
    @State private var navigation = AppNavigation()
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
            .task {
                // Defer SwiftData container init until after the first frame so
                // the lock screen renders without waiting on store/CloudKit setup.
                // .task fires after onAppear, on @MainActor.
                if modelContainer == nil {
                    modelContainer = OpenFeelingsApp.makeModelContainer()
                }
            }
        }
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([FeelingLog.self, Intention.self])

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
