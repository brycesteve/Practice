//
//  SleepConsistency.swift
//  Practice
//
//  Created by Steve Bryce on 16/08/2025.
//
import HealthKit

extension ReadinessManager {
    /// Computes a 0–100 score based on the variance of sleep start times over the past 7 days.
    func sleepConsistencyScore() async throws -> Double {
        let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: .sevenDaysAgo, end: .now)
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)], sortDescriptors: [.init(\.startDate, order: .forward)])
        let samples: [HKCategorySample] = try await descriptor.result(for: healthStore)
        
        // Extract start hours for "main sleep blocks" (longest block each night)
        var startHours: [Double] = []
        let calendar = Calendar.current
        
        // Group samples by day
        let groupedByDay = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.startDate)
        }
        
        for (_, dailySamples) in groupedByDay {
            // Pick the longest asleep block
            let asleepSamples = dailySamples.compactMap { sample -> (start: Date, duration: TimeInterval)? in
                guard let stage = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                      HKCategoryValueSleepAnalysis.allAsleepValues.contains(stage) else { return nil }
                return (start: sample.startDate, duration: sample.endDate.timeIntervalSince(sample.startDate))
            }
            guard let longest = asleepSamples.max(by: { $0.duration < $1.duration }) else { continue }
            let hour = Double(calendar.component(.hour, from: longest.start)) + Double(calendar.component(.minute, from: longest.start)) / 60
            startHours.append(hour)
        }
        
        guard startHours.count > 1 else { return 100 } // if not enough data, full score
        
        // Compute standard deviation in hours
        let mean = startHours.reduce(0, +) / Double(startHours.count)
        let variance = startHours.map { pow($0 - mean, 2) }.reduce(0, +) / Double(startHours.count)
        let stdDev = sqrt(variance)
        
        // Map stdDev (0–3 hours typical) to 0–100 score
        let clamped = min(stdDev, 3)
        let score = 100 * (1 - clamped / 3)
        return score
    }
}
