import SwiftData
import SwiftUI

@main
struct OpenFeelingsApp: App {
    private let modelContainer = OpenFeelingsApp.makeModelContainer()

    @State private var healthService = HealthService()

    var body: some Scene {
        WindowGroup {
            LockGateView {
                RootView()
            }
            .environment(healthService)
            .modelContainer(modelContainer)
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([FeelingLog.self])

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

        let cloudConfiguration = ModelConfiguration(
            "OpenFeelingsCloud",
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.tfinklea.openfeelings")
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
    }
}
