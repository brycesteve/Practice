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
    @State var globalState = GlobalLoadingState()
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

