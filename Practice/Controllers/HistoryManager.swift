//
//  HistoryController.swift
//  Practice
//
//  Created by Steve Bryce on 08/06/2025.
//
import SwiftUI
import HealthKit


@MainActor
@Observable
class HistoryManager {
    var healthStore = HKHealthStore()
    
    nonisolated init() {}
    
    func requestAuthorization() async throws {
        
        try await healthStore.requestAuthorization(toShare: HKObjectType.typesToShare, read: HKObjectType.typesToRead)
    }
    
    func getPractices(from startDate: Date, to endDate: Date) async -> [HKWorkout] {
        do {
            let appPredicate = try await getAppPredicate()
            
            let datePredicate = HKQuery.predicateForSamples(withStart: Calendar.autoupdatingCurrent.startOfDay(for: startDate), end: Calendar.autoupdatingCurrent.startOfDay(for: endDate.addingTimeInterval(86400)))
            
            //let metaPredicate = HKQuery.predicateForObjects(withMetadataKey: "PracticeMeta")
            let queryDescriptor = HKSampleQueryDescriptor(predicates: [.workout(NSCompoundPredicate(andPredicateWithSubpredicates: [appPredicate, datePredicate]))], sortDescriptors: [SortDescriptor(\.startDate, order: .forward)])
            
            return try await queryDescriptor.result(for: healthStore)
        }
        catch {
            return []
        }
    }
    
    func getPracticedDates(from: Date, to: Date) async -> [Date]  {
        return await getPractices(from: from, to: to).map { workout in
            workout.startDate
        }
    }
    
    func getCompletedPracticesForDate(_ date: Date) async -> [HKWorkout] {
        return await getPractices(from: date, to: date)
    }
    
    
    private func getAppPredicate() async throws -> NSPredicate  {
        let sourceDescriptor = HKSourceQueryDescriptor(predicate: .workout())
        
        let sources = try await sourceDescriptor.result(for: healthStore)
        let appSources = sources.filter {
            $0.bundleIdentifier.hasPrefix("net.stevebryce.Practice")
        }
        return HKQuery.predicateForObjects(from: Set(appSources))
        
    }
    
    func getHeartRateRange(for workout: HKWorkout) async -> (low: Double, high: Double) {
        
        let heartRateType = HKQuantityType(.heartRate)
        //let predicate = HKQuery.predicateForObjects(from: workout)
        
        let stat = workout.statistics(for: heartRateType)
        let lowHR = stat?.minimumQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
        let highHR = stat?.maximumQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
        
        return (lowHR ?? 0, highHR ?? 0)

    }
}
