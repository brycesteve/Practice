//
//  PracticeDetail.swift
//  Practice
//
//  Created by Steve Bryce on 19/07/2025.
//
import SwiftUI
import HealthKit

@Observable
class PracticeDetailViewModel {
    init (from workout: HKWorkout) {
        self.date = workout.startDate
        
        if let name = workout.brandName, let practice = Practice(rawValue: name) {
            self.practice = practice
        }
        
        if workout.segments.count > 0 {
            self._segments = workout.segments.map {
                PracticeSegmentViewModel(
                    name: $0.key,
                    sets: $0.value.compactMap{ .init(from: $0) }
                )
            }
            
        }
        if let energy = workout.statistics(for: .quantityType(forIdentifier: .activeEnergyBurned)!) {
            self.totalActiveEnergy = energy.sumQuantity()?.doubleValue(for: .largeCalorie()) ?? 0
        }
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
}

struct PracticeSetViewModel {
    var description: String
    var weight: Int?
    var duration: TimeInterval
    
    init? (from activity: HKWorkoutActivity) {
        guard let exercise = Exercise.from(activity) else { return nil }
        
        self.description = exercise.description
        self.weight = exercise.weight
        self.duration = activity.duration
    }
}

struct PracticeSegmentViewModel {
    var name = ""
    var sets: [PracticeSetViewModel] = []
}
