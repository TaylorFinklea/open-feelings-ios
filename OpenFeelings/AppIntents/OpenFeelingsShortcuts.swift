// OpenFeelings/AppIntents/OpenFeelingsShortcuts.swift
import AppIntents

struct OpenFeelingsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFeelingIntent(),
            phrases: [
                "Log a feeling in \(.applicationName)",
                "Tell \(.applicationName) how I feel"
            ],
            shortTitle: "Log a feeling",
            systemImageName: "mic.fill"
        )
    }
}
