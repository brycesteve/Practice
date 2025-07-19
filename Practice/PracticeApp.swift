//
//  PracticeApp.swift
//  Practice
//
//  Created by Steve Bryce on 24/05/2025.
//

import SwiftUI
import OSLog

@main
struct PracticeApp: App {
    @Bindable var historyManager = HistoryManager()
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Dashboard", systemImage: "house") {
                    DashboardView()
                }
                Tab("History", systemImage: "calendar") {
                    HistoryView()
                }
            }
            .tint(.green)
            .environment(historyManager)
            .onAppear {
                Task {
                    do {
                        try await historyManager.requestAuthorization()
                    }
                    catch (let error) {
                        Logger.default.error("\(error.localizedDescription)")
                    }
                }
            }
            
        }
    }
}

