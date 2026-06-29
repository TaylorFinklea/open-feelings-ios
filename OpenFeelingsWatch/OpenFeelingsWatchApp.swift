import SwiftUI

@main
struct OpenFeelingsWatchApp: App {
    @State private var sessionClient: WatchSessionClient
    @State private var wizard = CheckInWizardState()
    @State private var settings = WatchSettingsStore()

    init() {
        _sessionClient = State(initialValue: WatchSessionClient.shared)
    }

    var body: some Scene {
        WindowGroup {
            CheckInRootView()
                .environment(sessionClient)
                .environment(wizard)
                .environment(settings)
                .task {
                    // Wiring after construction so both objects exist; the
                    // store may already be seeded from session.receivedApplicationContext.
                    sessionClient.settingsStore = settings
                }
        }
    }
}
