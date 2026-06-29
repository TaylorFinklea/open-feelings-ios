// OpenFeelingsWatch/AppIntents/WatchAppShortcuts.swift
import AppIntents

struct WatchAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WatchCheckInIntent(),
            phrases: [
                "Log a feeling in \(.applicationName)",
                "Tell \(.applicationName) how I feel"
            ],
            shortTitle: "Log a feeling",
            systemImageName: "mic.fill"
        )
    }
}
