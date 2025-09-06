//
//  PracticeWatchApp.swift
//  PracticeWatch Watch App
//
//  Created by Steve Bryce on 24/05/2025.
//

import SwiftUI
import Foundation
import AppIntents
import OSLog

@main
struct PracticeWatch_Watch_AppApp: App {
    @Bindable private var practiceManager = PracticeManager.shared
    @State var appState = WatchAppState()
    
    
    init(){
        _ = ConnectivityBridge.shared
        Task {
            do {
                try await PracticeManager.shared.requestAuthorization()
            }
            catch (let error) {
                Logger.default.error("\(error.localizedDescription)")
            }
        }
    }

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
            .environment(appState)
            .onReceive(NotificationCenter.default.publisher(for: .startPractice)) { notification in
                if let practiceName = notification.object as? String, let practice = Practice(rawValue: practiceName) {
                    practiceManager.selectedPractice = practice
                }
            }
            .onOpenURL { url in
                if url.absoluteString == "practice://readinessDetail" {
                    appState.showReadinessDetail = true
                }
            }
        }
    }
    
    @WKApplicationDelegateAdaptor var appDelegate: AppDelegate
}

@Observable
class WatchAppState {
    var showReadinessDetail = false
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        UserDefaults.standard.register(defaults: [
            Exercise.CodingKeys.squat.rawValue: 16,
            Exercise.CodingKeys.halo.rawValue: 16,
            Exercise.CodingKeys.swing.rawValue: 24,
            Exercise.CodingKeys.getUp.rawValue: 24
        ])
        PracticeAppShortcuts.updateAppShortcutParameters()
    }
}
