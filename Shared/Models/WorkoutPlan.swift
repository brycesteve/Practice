//
//  WorkoutPlan.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//

import Foundation

struct WorkoutPlan: Identifiable, Codable {
    let id: UUID
    let date: Date
    let routine: RoutineType
    let exercises: [PlannedExercise]
}
