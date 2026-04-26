//
//  PlanStore.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//
import Foundation

actor RoutineSync {
    private let key = "workout_plans"
    
    func save(_ plans: [WorkoutPlan]) {
        let data = try? JSONEncoder().encode(plans)
        UserDefaults(suiteName: "group.net.stevebryce.practice")?
            .set(data, forKey: key)
    }
    
    func loadPlans() -> [WorkoutPlan] {
        guard let data = UserDefaults(suiteName: "group.net.stevebryce.practice")?
            .data(forKey: key),
              let plans = try? JSONDecoder().decode([WorkoutPlan].self, from: data)
        else { return [] }
        
        return plans
    }
}
