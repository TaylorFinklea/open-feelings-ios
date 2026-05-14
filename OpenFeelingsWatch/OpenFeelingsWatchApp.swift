import SwiftUI

@main
struct OpenFeelingsWatchApp: App {
    @State private var sessionClient = WatchSessionClient()
    @State private var wizard = CheckInWizardState()

    var body: some Scene {
        WindowGroup {
            CheckInRootView()
                .environment(sessionClient)
                .environment(wizard)
        }
    }
}
