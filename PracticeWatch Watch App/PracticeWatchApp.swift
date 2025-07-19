//
//  PracticeWatchApp.swift
//  PracticeWatch Watch App
//
//  Created by Steve Bryce on 24/05/2025.
//

import SwiftUI

@main
struct PracticeWatch_Watch_AppApp: App {
    @Bindable private var practiceManager = PracticeManager()

    @SceneBuilder var body: some Scene {
        WindowGroup {
            //SinisterSettingsView()
            StartView()
            .sheet(isPresented: $practiceManager.showingSummaryView) {
                SummaryView()
            }
            .sheet(isPresented: $practiceManager.showingCountdownTimer) {
                if #available(watchOS 11.0, *) {
                    StartTimerView()
                        .toolbarVisibility(.hidden, for: .navigationBar)
                } else {
                    StartTimerView()
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
            
            .environment(practiceManager)
        }
    }
    
    @WKApplicationDelegateAdaptor var appDelegate: AppDelegate
}


class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        UserDefaults.standard.register(defaults: [
            Exercise.CodingKeys.squat.rawValue: 16,
            Exercise.CodingKeys.halo.rawValue: 16,
            Exercise.CodingKeys.swing.rawValue: 24,
            Exercise.CodingKeys.getUp.rawValue: 24
        ])
    }
}
