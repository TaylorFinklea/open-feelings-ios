// OpenFeelings/Services/OpenFeelingsModelContainer.swift
import SwiftData
import Foundation

/// The single SwiftData container for the whole process. The app scene and
/// any AppIntent both read `shared` — never construct another container, or
/// two stores point at the same CloudKit zone.
enum OpenFeelingsModelContainer {
    @MainActor
    static let shared: ModelContainer = make()

    @MainActor
    private static func make() -> ModelContainer {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self,
            ThoughtRecord.self
        ])

        #if DEBUG
        if CommandLine.arguments.contains("-screenshotMode") {
            let screenshotConfiguration = ModelConfiguration(
                "OpenFeelingsScreenshots", schema: schema,
                isStoredInMemoryOnly: true, cloudKitDatabase: .none
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
                "OpenFeelingsTests", schema: schema,
                isStoredInMemoryOnly: true, cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [testConfiguration])
            } catch {
                fatalError("Unable to create Open Feelings test model container: \(error)")
            }
        }

        #if targetEnvironment(simulator)
        let simulatorConfiguration = ModelConfiguration(
            "OpenFeelingsSimulator", schema: schema, cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [simulatorConfiguration])
        } catch {
            fatalError("Unable to create Open Feelings simulator model container: \(error)")
        }
        #else
        let cloudConfiguration = ModelConfiguration(
            "OpenFeelingsCloud", schema: schema,
            cloudKitDatabase: .private("iCloud.dev.finklea.openfeelings")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            let localConfiguration = ModelConfiguration(
                "OpenFeelingsLocal", schema: schema, cloudKitDatabase: .none
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
