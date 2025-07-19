//
//  PracticeSummary.swift
//  Practice
//
//  Created by Steve Bryce on 12/07/2025.
//

import SwiftUI
import Foundation
import HealthKit

@Observable
class PracticeSummary {
    init(from workout: HKWorkout) {
        self.workout = workout
        if let metadata = workout.metadata {
            if let name = metadata[HKMetadataKeyWorkoutBrandName] as? String {
                self.name = name
                if let practice = Practice(rawValue: name) {
                    self.practice = practice
                    
                    let historyManager = HistoryManager()
                    Task {
                        let range = await historyManager.getHeartRateRange(for: workout)
                        self.heartRateRange = "\(range.low.formatted(.number.precision(.fractionLength(0))))-\(range.high.formatted(.number.precision(.fractionLength(0))))"
                    }
                }
            }
            
        }
    }
    
    private var workout: HKWorkout!
    private var practice: Practice?
    
    var name: String = ""
    
    var image: Image? {
        practice?.image ?? nil
    }
    
    
    var duration: String {
        guard practice != nil else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated

        return formatter.string(from: workout.duration) ?? ""
    }
    
    var date: Date {
        return workout.startDate
    }
    
    var heartRateRange: String = ""
}


