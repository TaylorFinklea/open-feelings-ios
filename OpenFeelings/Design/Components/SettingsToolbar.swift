import SwiftUI

/// Adds a trailing gear button to a tab's navigation bar that opens the
/// app-wide Settings sheet. Apply to each top-level tab's root content.
struct SettingsToolbar: ViewModifier {
    @Environment(AppNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigation.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityIdentifier("settings.gear")
                .accessibilityLabel("Settings")
            }
        }
    }
}

extension View {
    func settingsToolbar() -> some View { modifier(SettingsToolbar()) }
}
