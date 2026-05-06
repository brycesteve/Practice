// TrainingApp.swift — iOS
// Uses makeiOS() which enables CloudKit sync automatically.

import SwiftUI
import SwiftData

@main
struct TrainingApp: App {
    
    private let container: ModelContainer = {
        do { return try ModelContainer.makeiOS() }
        catch { fatalError("Failed to create SwiftData/CloudKit container: \(error)") }
    }()
    
    private let wcDelegate: iOSWatchConnectivityDelegate
    private let errorState = ErrorState()
    
    init() {
        BackgroundTaskManager.shared.registerBackgroundTasks()
        let delegate = iOSWatchConnectivityDelegate(modelContainer: container)
        wcDelegate = delegate
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .errorBanner()
                .task { await onLaunch() }
        }
        .modelContainer(container)
        .environment(errorState)
    }
    
    private func onLaunch() async {
        do { try await HealthKitManager.shared.requestAuthorization() }
        catch { errorState.post("HealthKit authorisation failed."); return }
        
        _ = try? await NotificationManager.shared.requestAuthorization()
        
        BackgroundTaskManager.shared.enableHealthKitBackgroundDelivery(modelContainer: container)
        BackgroundTaskManager.shared.scheduleNextRefresh()
        
        WatchConnectivityManager.shared.activate()
        WatchConnectivityManager.shared.delegate = wcDelegate
        
        await wcDelegate.sendFullSyncToWatch()
    }
}
