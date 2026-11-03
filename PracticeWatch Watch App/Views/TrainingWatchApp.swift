// TrainingWatchApp.swift — watchOS
// Uses makeWatch() — local store only, no CloudKit.
// WatchConnectivity handles the real-time sync bridge with iOS.

import SwiftUI

@main
struct TrainingWatchApp: App {
    @State private var showRecovery = false
    private let errorState = ErrorState()
    
    init() {
        if !PracticeExecution.isTesting { WatchConnectivityManager.shared.activate() }
    }
    
    var body: some Scene {
        WindowGroup {
            if PracticeExecution.isTesting {
                Color.clear
            } else {
                NavigationStack {
                    SessionPickerView()
                        .navigationDestination(isPresented: $showRecovery) {
                            WatchRecoveryView()
                        }
                }
                .errorBanner()
                .onOpenURL { url in
                    if url.host == "recovery" { showRecovery = true }
                }
                .task {
                    try? await HealthKitManager.shared.requestAuthorization()
                }
            }
        }
        .environment(errorState)
    }
}
