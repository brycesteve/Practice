// TrainingWatchApp.swift — watchOS
// Uses makeWatch() — local store only, no CloudKit.
// WatchConnectivity handles the real-time sync bridge with iOS.

import SwiftUI
import SwiftData

@main
struct TrainingWatchApp: App {
    @State private var showRecovery = false
    private let errorState = ErrorState()
    
    init() {
        WatchConnectivityManager.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SessionPickerView()
                    .navigationDestination(isPresented: $showRecovery) {
                        WatchRecoveryView()
                    }
            }
            .errorBanner()
            .onOpenURL { url in
                print(url)
                if url.host == "recovery" { showRecovery = true }
            }
            .task {
                try? await HealthKitManager.shared.requestAuthorization()
            }
        }
        .modelContainer(try! ModelContainer.makeWatch())
        .environment(errorState)
        
        
    }
}
