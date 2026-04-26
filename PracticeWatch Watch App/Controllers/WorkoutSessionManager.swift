//
//  WorkoutSessionManager.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//


import HealthKit
import WatchKit

final class WorkoutSessionManager: NSObject, ObservableObject {

    private let healthStore = HKHealthStore()

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var isActive = false

    // MARK: Start

    func startWorkout() {
        let config = HKWorkoutConfiguration()
        config.activityType = .functionalStrengthTraining
        config.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()

            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )

            session?.delegate = self
            builder?.delegate = self

            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("Begin collection error:", error)
                }
            }

            isActive = true

        } catch {
            print("Workout start failed: \(error)")
        }
    }

    // MARK: End

    func endWorkout() {
        let endDate = Date()

        session?.end()
        builder?.endCollection(withEnd: endDate) { [weak self] _, _ in
            self?.builder?.finishWorkout { workout, error in
                self?.isActive = false
            }
        }
    }
}

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        // You can mirror UI state here if needed
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print(error)
    }
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // future: segment detection, HR spikes etc.
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // future: live HR, energy, etc.
    }
}
