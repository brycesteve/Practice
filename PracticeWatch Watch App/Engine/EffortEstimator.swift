//
//  EffortEstimator.swift
//  Practice
//
//  Created by Steve Bryce on 22/06/2025.
//

import Foundation
import HealthKit

class EffortScoreEstimator {

    struct Config {
        let zoneWeights: [Int: Double] = [1: 1.0, 2: 2.0, 3: 3.0, 4: 4.5, 5: 6.0]
        let minActiveZone = 2
        let excludeRestPeriods = true
        //let effortMetadataKey = "EffortScore"
    }

    func estimateEffortScore(
        for workout: HKWorkout, using healthStore: HKHealthStore
    ) async throws -> Double {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return 0
        }

        var age: Int?
        do {
            let birthday = try healthStore.dateOfBirthComponents()
            if let year = birthday.year {
                let now = Calendar.current.component(.year, from: Date())
                age = now - year
            }
        } catch {
            print("Could not retrieve date of birth: \(error)")
        }

        guard let userAge = age else {
            return 0
        }

        let maxHR = 220 - Double(userAge)

        
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [])
        
        let queryDescriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: heartRateType, predicate: predicate)], sortDescriptors: [])
        
        let samples = try await queryDescriptor.result(for: healthStore)
            
        let score = self.calculateEffortScore(
            from: samples,
            workout: workout,
            maxHR: maxHR
        )
        return max(score, 1)
    }

    private func totalActiveEnergyBurned(for workout: HKWorkout) -> Double {
        if let stats = workout.statistics(for: HKQuantityType(.activeEnergyBurned)) {
            return stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }
        return 0
    }

    private func calculateEffortScore(from samples: [HKQuantitySample], workout: HKWorkout, maxHR: Double) -> Double {
        let config = Config()
        var zoneDurations: [Int: TimeInterval] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]

        for sample in samples {
            let hr = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            let percentage = hr / maxHR

            let zone: Int
            switch percentage {
            case 0..<0.6: zone = 1
            case 0.6..<0.7: zone = 2
            case 0.7..<0.8: zone = 3
            case 0.8..<0.9: zone = 4
            default: zone = 5
            }

            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            if config.excludeRestPeriods && zone < config.minActiveZone {
                continue
            }

            zoneDurations[zone, default: 0] += duration
        }

        let totalZoneDuration = zoneDurations.values.reduce(0, +)
        guard totalZoneDuration > 0 else { return 0 }

        let weightedEffort = zoneDurations.reduce(0.0) { total, entry in
            let (zone, duration) = entry
            return total + (config.zoneWeights[zone, default: 0] * duration)
        }

        // 🔥 Active energy burned weight
        let energyBurned = totalActiveEnergyBurned(for: workout)
        let duration = workout.duration
        let kcalPerMin = duration > 0 ? energyBurned / (duration / 60.0) : 0
        let energyWeight = min(1.5, max(0.75, kcalPerMin / 10.0))  // Normalize around 10 kcal/min

        // 💪 Workout type multiplier
        let typeMultiplier = self.workoutTypeMultiplier(for: workout.workoutActivityType)

        let rawScore = (weightedEffort / totalZoneDuration) * 10.0
        let adjustedScore = min(100.0, rawScore * energyWeight * typeMultiplier)

        return adjustedScore
    }

    private func workoutTypeMultiplier(for type: HKWorkoutActivityType) -> Double {
        switch type {
        case .traditionalStrengthTraining:
            return 1.0
        case .functionalStrengthTraining:
            return 1.15
        case .highIntensityIntervalTraining:
            return 1.25
        default:
            return 1.0
        }
    }

    @available(watchOS 11.0, *)
    func saveEffortScoreToHealthKit(score: Double, for workout: HKWorkout, using healthStore: HKHealthStore) async throws {
        let effort = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .estimatedWorkoutEffortScore)!,
            quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: score),
            start: workout.startDate,
            end: workout.endDate
        )
        try await healthStore.relateWorkoutEffortSample(effort, with: workout, activity: nil)
    }
}
