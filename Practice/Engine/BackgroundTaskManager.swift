// BackgroundTaskManager.swift — iOS only
// Owns two background update mechanisms:
//
//  1. HealthKit Background Delivery (primary)
//     HKObserverQuery watches HRV, resting HR, and sleep. When the Watch
//     writes new samples (typically early morning), HealthKit wakes the iOS
//     app in the background and we compute + cache today's recovery score.
//
//  2. BGAppRefreshTask (fallback)
//     Fires once per day. Catches days where HealthKit delivery didn't fire
//     (e.g. no new samples, Watch not worn). Scheduled ~06:00 each morning.
//
// Setup required in Xcode:
//  • Info.plist: add "BGTaskSchedulerPermittedIdentifiers" array with
//    "com.yourname.TrainingApp.recoveryRefresh"
//  • Signing & Capabilities → Background Modes:
//    ✓ Background fetch
//    ✓ Background processing
//    ✓ HealthKit background delivery  (implicit via HKObserverQuery)

import Foundation
import HealthKit
import BackgroundTasks
import SwiftData
import WidgetKit

public final class BackgroundTaskManager {
    
    public static let shared = BackgroundTaskManager()
    
    public let refreshTaskIdentifier = "net.stevebryce.practice.recoveryRefresh"
    
    // MARK: - Registration (call once at app launch, before app becomes active)
    
    /// Call this in TrainingApp.init() — must happen before the app finishes launching.
    public func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    // MARK: - HealthKit Background Delivery (primary mechanism)
    
    /// Enables HealthKit background delivery for the recovery-relevant types
    /// and installs long-lived HKObserverQueries.
    /// Call this after HealthKit authorisation is granted.
    public func enableHealthKitBackgroundDelivery(modelContainer: ModelContainer) {
        let store = HKHealthStore()
        
        let types: [(HKQuantityTypeIdentifier, HKUpdateFrequency)] = [
            (.heartRateVariabilitySDNN, .hourly),
            (.restingHeartRate,         .hourly),
            (.respiratoryRate,          .hourly),
        ]
        let sleepType = HKCategoryType(.sleepAnalysis)
        
        // Enable background delivery for quantity types
        for (identifier, frequency) in types {
            let quantityType = HKQuantityType(identifier)
            store.enableBackgroundDelivery(for: quantityType, frequency: frequency) { success, error in
                if let error { print("BG delivery enable error (\(identifier.rawValue)): \(error)") }
            }
            
            // Observer query — fires when new samples of this type are saved
            let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { _, completionHandler, error in
                guard error == nil else { completionHandler(); return }
                Task {
                    await self.computeAndCacheScore(modelContainer: modelContainer)
                    completionHandler()   // MUST call this or HealthKit stops delivery
                }
            }
            store.execute(query)
        }
        
        // Sleep analysis
        store.enableBackgroundDelivery(for: sleepType, frequency: .daily) { _, _ in }
        let sleepQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completionHandler, error in
            guard error == nil else { completionHandler(); return }
            Task {
                await self.computeAndCacheScore(modelContainer: modelContainer)
                completionHandler()
            }
        }
        store.execute(sleepQuery)
    }
    
    // MARK: - BGAppRefreshTask handler (fallback)
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh before doing any work
        scheduleNextRefresh()
        
        let taskHandle = Task {
            do {
                let container = try ModelContainer.makeiOS()
                await computeAndCacheScore(modelContainer: container)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            taskHandle.cancel()
        }
    }
    
    /// Schedule the next daily refresh for ~06:00 tomorrow.
    public func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        
        var components       = DateComponents()
        components.hour      = 5
        components.minute    = 30
        let nextMorning      = Calendar.current.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(86400)
        
        request.earliestBeginDate = nextMorning
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BGTaskScheduler submit error: \(error)")
        }
    }
    
    // MARK: - Core computation + SwiftData cache (shared by both mechanisms)
    
    /// Computes today's recovery score and upserts it into SwiftData.
    /// Safe to call from background — creates its own model context.
    @MainActor
    func computeAndCacheScore(modelContainer: ModelContainer) async {
        do {
            let engine = RecoveryEngine()
            let result = try await engine.computeScore()
            
            let context = modelContainer.mainContext
            let today   = Calendar.current.startOfDay(for: Date())
            
            // Fetch existing record for today (upsert pattern)
            let descriptor = FetchDescriptor<RecoveryScoreRecord>(
                predicate: #Predicate { $0.date >= today }
            )
            let existing = try context.fetch(descriptor).first
            
            let record: RecoveryScoreRecord
            if let e = existing {
                record = e
            } else {
                let r = RecoveryScoreRecord(date: today, overallScore: result.overall)
                context.insert(r)
                record = r
            }
            
            record.overallScore          = result.overall
            record.hrvScore              = result.hrvContribution
            record.restingHRScore        = result.restingHRContribution
            record.sleepDurationScore    = result.sleepDurationContribution
            record.sleepQualityScore     = result.sleepQualityContribution
            record.respiratoryRateScore  = result.respiratoryContribution
            record.trainingLoadScore     = result.trainingLoadContribution
            record.hrv                   = result.metrics.hrv
            record.restingHR             = result.metrics.restingHeartRate
            record.sleepHours            = result.metrics.sleepDuration
            record.respiratoryRate       = result.metrics.respiratoryRate
            record.activeEnergyYesterday = result.metrics.activeEnergyYesterday
            
            try context.save()
            
            // Fire low-recovery notification if warranted
            if result.overall < 35 {
                NotificationManager.shared.notifyLowRecovery(score: result.overall)
            }
            
            // Reload complication timelines so the watch face shows the fresh score
            WidgetCenter.shared.reloadAllTimelines()
            
            // Push updated score to watch via WatchConnectivity
            await syncScoreToWatch(result.overall, modelContainer: modelContainer)
            
        } catch {
            print("Background recovery compute error: \(error)")
        }
    }
    
    /// Build a full WCSyncPayload from SwiftData and send it to the watch.
    /// Called after every background recovery score write so the watch
    /// complication and WatchRecoveryView stay current without touching HealthKit.
    @MainActor private func syncScoreToWatch(_ score: Double, modelContainer: ModelContainer) async {
        do {
            let context = modelContainer.mainContext
            
            // Fetch skill progressions
            let progressionRecords = try context.fetch(FetchDescriptor<SkillProgressionRecord>())
            let progressions = progressionRecords.map { $0.toSkillProgression() }
            
            // Fetch settings
            let settings = try context.fetch(FetchDescriptor<AppSettings>()).first ?? AppSettings()
            
            // Fetch recent workout count
            let workoutCount = try context.fetchCount(FetchDescriptor<WorkoutRecord>())
            
            let payload = WCSyncPayload(
                skillProgressions: progressions,
                eveningRotationDay: settings.eveningRotationDay,
                targetSwingWeightKg: settings.targetSwingWeightKg,
                targetTGUWeightKg: settings.targetTGUWeightKg,
                recentWorkoutCount: workoutCount,
                todayRecoveryScore: score
            )
            
            WatchConnectivityManager.shared.sendFullSync(payload: payload)
        } catch {
            print("syncScoreToWatch error: \(error)")
        }
    }
}
