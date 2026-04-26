//
//  RoutineSession.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//

import SwiftUI

final class RoutineSession: ObservableObject {

    let plan: WorkoutPlan

    @Published var currentIndex: Int = 0
    @Published var isCompleted: Bool = false

    init(plan: WorkoutPlan) {
        self.plan = plan
    }

    var currentExercise: PlannedExercise {
        plan.exercises[currentIndex]
    }

    func advance() {
        guard currentIndex < plan.exercises.count - 1 else {
            completeSession()
            return
        }

        currentIndex += 1
    }

    private func completeSession() {
        isCompleted = true
    }
}
