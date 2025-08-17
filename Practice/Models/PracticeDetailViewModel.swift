//
//  PracticeDetail.swift
//  Practice
//
//  Created by Steve Bryce on 19/07/2025.
//
import SwiftUI
import HealthKit
import OSLog

@Observable
class PracticeDetailViewModel {
    init (from workout: HKWorkout) {
        self.date = workout.startDate
        
        if let name = workout.brandName, let practice = Practice(rawValue: name) {
            self.practice = practice
        }
        
        if workout.segments.count > 0 {
            self._segments = workout.segments.map {
                return PracticeSegmentViewModel(
                    name: $0.segmentName,
                    startDate: $0.startDate,
                    endDate: $0.endDate ?? .now,
                    sets: $0.exerciseEvents.compactMap{ .init(from: $0) },
                    activity: $0,
                    workRestRatio: $0.workToRestRatio
                )
            }
        }
        if let energy = workout.statistics(for: .quantityType(forIdentifier: .activeEnergyBurned)!) {
            self.totalActiveEnergy = energy.sumQuantity()?.doubleValue(for: .largeCalorie()) ?? 0
        }
        duration = workout.duration
        if let hr = workout.statistics(
            for: .quantityType(forIdentifier: .heartRate)!
        ) {
            self.avgHR = hr
                .averageQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
        }
        tonnage = Double(workout.simpleAndSinisterWeight)
        workToRestRatio = workout.workToRestRatio
    }
    var practice: Practice?
    var name: String {
        return practice?.name ?? "Practice"
    }
    private var _segments: [PracticeSegmentViewModel] = []
    var segments: [PracticeSegmentViewModel] {
        guard practice != nil else {
            return _segments
        }
        return _segments.sorted(by: { left, right in
            practice?.segmentOrder[left.name] ?? .max < practice?.segmentOrder[right.name] ?? .max
        })
    }
    var date: Date!
    
    var totalActiveEnergy: Double = 0
    var duration: TimeInterval = 0
    var avgHR: Double = 0
    var tonnage: Double = 0
    var workToRestRatio: WorkRestRatio
    
    
    
}

@Observable
class PracticeSetViewModel {
    var description: String
    var weight: Int?
    var duration: TimeInterval
    var repsOrDuration: String
    var lowHR: Double = 0
    var highHR: Double = 0
    
    
    
    init? (from event: HKWorkoutEvent) {
        guard let exercise = Exercise.from(event) else { return nil }
        
        self.description = exercise.description
        self.weight = exercise.weight
        self.duration = event.dateInterval.duration
        self.repsOrDuration = exercise == .rest ? Duration
            .seconds(event.dateInterval.duration
            ).formatted(
                .units(width: .narrow)
            ) : exercise.repsOrDuration
        Task {
            let hrRange = await HistoryManager.shared.getHeartRateRange(for: event)
            self.lowHR = hrRange.low
            self.highHR = hrRange.high
            
        
        }
        
    }
}

@Observable
class PracticeSegmentViewModel {
    var name = ""
    var startDate: Date
    var endDate: Date
    var sets: [PracticeSetViewModel] = []
    var heartRateDataPoints: [(Date, Double)] = []
    var workRestRatio: WorkRestRatio
    
    
    init(
        name: String = "",
        startDate: Date,
        endDate: Date,
        sets: [PracticeSetViewModel],
        activity: HKWorkoutActivity,
        workRestRatio: WorkRestRatio
    ) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.sets = sets
        self.workRestRatio = workRestRatio

        Task {
            let hrDatapoints = await HistoryManager.shared.getHeartRateDatapoints(
                for: activity)
            self.heartRateDataPoints = hrDatapoints
            Logger.default.debug("HR Datapoints: \(self.heartRateDataPoints, privacy: .public)")
        }
        
    }
}
