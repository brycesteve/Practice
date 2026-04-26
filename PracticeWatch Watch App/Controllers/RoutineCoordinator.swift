//
//  RoutineCoordinator.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//

import HealthKit

@MainActor
final class RoutineCoordinator: ObservableObject {
    
    // MARK: Input
    let plan: WorkoutPlan
    
    // MARK: State
    @Published var currentIndex: Int = 0
    @Published var isRunning: Bool = false
    @Published var isFinished: Bool = false
    
    // MARK: Dependencies
    let workoutSession = WorkoutSessionManager()
    
    init(plan: WorkoutPlan) {
        self.plan = plan
    }
    
    // MARK: Lifecycle
    
    func start() {
        isRunning = true
        workoutSession.startWorkout()
    }
    
    func next() {
        guard currentIndex < plan.exercises.count - 1 else {
            finish()
            return
        }
        
        currentIndex += 1
    }
    
    func finish() {
        isRunning = false
        isFinished = true
        workoutSession.endWorkout(plan: plan)
    }
    
    // MARK: Helpers
    
    var currentExercise: PlannedExercise {
        plan.exercises[currentIndex]
    }
}
