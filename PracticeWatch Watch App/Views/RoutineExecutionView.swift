//
//  RoutineExecutionView.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//

import SwiftUI

struct RoutineExecutionView: View {

    @StateObject private var session: RoutineSession

    init(plan: WorkoutPlan) {
        _session = StateObject(wrappedValue: RoutineSession(plan: plan))
    }

    var body: some View {
        VStack(spacing: 12) {

            Text(session.currentExercise.name)
                .font(.headline)

            exerciseDetails

            Button(action: {
                session.advance()
            }) {
                Text(session.isCompleted ? "Done" : "Next")
            }
        }
        .padding()
    }
    
    private var exerciseDetails: some View {
        VStack {
            if let sets = session.currentExercise.sets {
                Text("Sets: \(sets)")
            }
            
            if let reps = session.currentExercise.reps {
                Text("Reps: \(reps)")
            }
            
            if let weight = session.currentExercise.weightKg {
                Text("Weight: \(weight, specifier: "%.0f") kg")
            }
            
            if let duration = session.currentExercise.duration {
                Text("Duration: \(duration)s")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
