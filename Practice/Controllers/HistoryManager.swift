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
    
    static var shared = HistoryManager()
    
    private nonisolated init() {}
    
    func requestAuthorization() async throws {
        
        try await healthStore.requestAuthorization(toShare: HKObjectType.typesToShare, read: HKObjectType.typesToRead)
        ReadinessManager.shared.setupObserversIfNeeded()
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
    
    func getHeartRateRange(for event: HKWorkoutEvent) async -> (low: Double, high: Double) {
        let heartRateType = HKQuantityType(.heartRate)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: event.dateInterval.start,
            end: event.dateInterval.end
        )
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: heartRateType, predicate: predicate),
            options: [.discreteMax, .discreteMin]
        )
        let samples = try? await query.result(for: healthStore)
        let lowHR = samples?.minimumQuantity()?.doubleValue(
            for: .count().unitDivided(by: .minute())
        )
        let highHR = samples?.maximumQuantity()?.doubleValue(
            for: .count().unitDivided(by: .minute())
        )
        return (low: lowHR ?? 0, high: highHR ?? 0)
    }
    
    func getHeartRateDatapoints(for activity: HKWorkoutActivity) async -> [(Date, Double)] {
        var points: [(Date, Double)] = []
        var events = activity.exerciseEvents
        for event in events {
            let predicate = HKQuery.predicateForSamples(
                withStart: event.dateInterval.start,
                end: event.dateInterval.end
            )
            let desc = HKStatisticsQueryDescriptor(
                predicate:
                        .quantitySample(
                            type: HKQuantityType(.heartRate),
                            predicate: predicate
                        ),
                options: [.discreteAverage]
            )
            if let stat = try? await desc.result(for: healthStore),
               let avg = stat.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) {
                points.append((event.dateInterval.start, avg))
            }
        }
        return points
    }
    
    func calculateWeeklyTonnage(endingOn endDate: Date = .now) async -> Double {
        let startOfWeek = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        let workouts = await getPractices(from: startOfWeek, to: endDate)
        
        // Assumes tonnage is saved in metadata for each workout
        let total = workouts.compactMap { workout in
            workout.simpleAndSinisterWeight
        }.reduce(0, +)
        
        return Double(total)
    }
}

extension HistoryManager {
    func fetchVO2MaxSamples(limit: Int = 20) async -> [HKQuantitySample] {
        let type = HKQuantityType(.vo2Max)
        
        let queryDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [.init(\.startDate,  order: .reverse)],
            limit: limit
        )
        
        do {
            return try await queryDescriptor.result(for: healthStore)
        } catch {
            return []
        }
    }
}
