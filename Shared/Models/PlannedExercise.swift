//
//  PlannedExercise.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//

import Foundation


struct PlannedExercise: Identifiable, Codable {
    let id: UUID
    
    let name: String
    let type: ExerciseType
    
    let sets: Int?
    let reps: Int?
    let duration: Int? // seconds
    
    let weightKg: Double?   // 🔑 kettlebell use case
}
