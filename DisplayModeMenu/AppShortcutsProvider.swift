//
//  AppShortcutsProvider.swift
//  DisplayModeMenu
//
//  Exposes App Shortcuts to the Shortcuts app.
//

import AppIntents

struct DisplayModeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetDisplayModeIntent(),
            phrases: [
                "Set display to \(.applicationName)",
                "Change display resolution in \(.applicationName)",
                "Set display mode in \(.applicationName)"
            ],
            shortTitle: "Set Display Mode",
            systemImageName: "display"
        )
    }
}
