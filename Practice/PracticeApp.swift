//
//  PracticeApp.swift
//  Practice
//
//  Created by Steve Bryce on 24/05/2025.
//

import SwiftUI
import OSLog
import BackgroundTasks
import HealthKit
import UserNotifications

@main
struct PracticeApp: App {
    @Bindable var historyManager = HistoryManager.shared
    @Bindable var readinessManager = ReadinessManager.shared
    @State var globalState = GlobalLoadingState()
    
    init() {
        _ = ConnectivityBridge.shared
        Task {
            do {
                try await HistoryManager.shared.requestAuthorization()
            }
            catch (let error) {
                Logger.default.error("\(error.localizedDescription)")
            }
        }
    }
    
    
    
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Dashboard", systemImage: "rectangle.stack.fill") {
                    DashboardView()
                }
                Tab("History", systemImage: "calendar") {
                    HistoryView()
                }
            }
            .tint(.green)
            .environment(historyManager)
            .environment(globalState)
            .environment(readinessManager)
            .onAppear {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                    if success {
                        print("All set!")
                    } else if let error {
                        print(error.localizedDescription)
                    }
                }
            }
            
            
        }
    }
}

