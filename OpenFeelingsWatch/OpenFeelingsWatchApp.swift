import SwiftUI

@main
struct OpenFeelingsWatchApp: App {
    @State private var sessionClient = WatchSessionClient()

    var body: some Scene {
        WindowGroup {
            CheckInRootView()
                .environment(sessionClient)
        }
    }
}
