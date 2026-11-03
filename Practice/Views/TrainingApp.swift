// TrainingApp.swift — iOS
// Uses makeiOS() which enables CloudKit sync automatically.

import SwiftUI
import SwiftData

@main
struct TrainingApp: App {
    
    @Environment(\.scenePhase) var scenePhase
    
    private let container: ModelContainer = {
        if PracticeExecution.isTesting {
            do {
                return try ModelContainer(for: Schema(CurrentSchema.models),
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            } catch { fatalError("Failed to create isolated test container: \(error)") }
        }
#if DEBUG && targetEnvironment(simulator)
        if BodyStatsSamples.isEnabled { return BodyStatsSamples.fixture.container }
#endif
        do { return try ModelContainer.makeiOS() }
        catch { fatalError("Failed to create SwiftData/CloudKit container: \(error)") }
    }()
    
    private let wcDelegate: iOSWatchConnectivityDelegate
    private let errorState = ErrorState()
    
    init() {
        if PracticeExecution.isTesting {
            wcDelegate = iOSWatchConnectivityDelegate(modelContainer: container)
            return
        }
#if DEBUG && targetEnvironment(simulator)
        if !BodyStatsSamples.isEnabled { BackgroundTaskManager.shared.registerBackgroundTasks() }
#else
        BackgroundTaskManager.shared.registerBackgroundTasks()
#endif
        let delegate = iOSWatchConnectivityDelegate(modelContainer: container)
        wcDelegate = delegate
    }
    
    var body: some Scene {
        WindowGroup {
            if PracticeExecution.isTesting {
                Color.clear
            } else {
#if DEBUG && targetEnvironment(simulator)
                if BodyStatsSamples.isEnabled {
                    BodyStatsSampleScreen()
                } else {
                    ContentView().errorBanner().task { await onLaunch() }
                }
#else
                ContentView().errorBanner().task { await onLaunch() }
#endif
            }
        }
        .modelContainer(container)
        .environment(errorState)
        .onChange(of: scenePhase, initial: true) { _, phase  in
#if DEBUG && targetEnvironment(simulator)
            if BodyStatsSamples.isEnabled { return }
#endif
            if PracticeExecution.isTesting { return }
            if phase == .active {
                BackgroundTaskManager.shared.scheduleNextRefresh()
            }
            
        }
    }
    
    private func onLaunch() async {
        do { try await HealthKitManager.shared.requestAuthorization() }
        catch { errorState.post("HealthKit authorisation failed. Practice measurements can still be saved.") }
        
        _ = try? await NotificationManager.shared.requestAuthorization()
        
        BackgroundTaskManager.shared.enableHealthKitBackgroundDelivery(modelContainer: container)
        //BackgroundTaskManager.shared.scheduleNextRefresh()
        
        WatchConnectivityManager.shared.delegate = wcDelegate
        WatchConnectivityManager.shared.activate()
        
        await wcDelegate.sendFullSyncToWatch()
        await BodyMeasurementStore.retryHealthExports(in: container.mainContext)
    }
}
