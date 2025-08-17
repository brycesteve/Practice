//
//  PracticeAppShortcuts.swift
//  Practice
//
//  Created by Steve Bryce on 26/07/2025.
//

import AppIntents

struct PracticeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPracticeIntent(),
            phrases: [
                "\(.applicationName) \(\.$practice)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Practice",
            systemImageName: "dumbbell.fill"
        )
    }
}
