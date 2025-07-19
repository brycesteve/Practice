//
//  WorkoutManager.swift
//  Practice
//
//  Created by Steve Bryce on 24/05/2025.
//


/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The workout manager that interfaces with HealthKit.
*/

import Foundation
import HealthKit
import SwiftUI
import OSLog

@MainActor
@Observable
class PracticeManager: NSObject {
    
    /**
     Practices to show on menu
     */
    var availablePractices: [Practice] = Practice.allCases
    
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?

    
    
    // MARK: - Modal Views Page
    
    var settingsView: (any View)?
    
    /**
     Show Settings page for the current practice
     */
    var showingSettingsForPractice: Bool = false {
        didSet {
            if !showingSettingsForPractice {
                //DispatchQueue.main.async {
                    self.settingsView = nil
                //}
            }
        }
    }
    
    var showingCountdownTimer: Bool = false
    {
        didSet {
            if oldValue, !showingCountdownTimer {
                startPractice()
            }
        }
    }
    
    func startCountdown() {
        //DispatchQueue.main.async {
            if self.showingSettingsForPractice {
                self.showingSettingsForPractice = false
            }
            self.showingCountdownTimer = true
            
            self.running = true
        //}
       
    }
    
    var showingSummaryView: Bool = false {
        didSet {
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    
    // MARK: - Completed Set Management
    
    /*
     Store completed sets here, for adding as MetaData
     */
    //var completedPractice: CompletedPractice?
    
    
    
//    func addCompletedSet() {
//        guard completedPractice != nil, currentSegment != nil, currentSetIndex != nil else { return }
//        
//        completedPractice?.sets.append(
//            CompletedPracticeSet(
//                reps: currentSegment!.sets[currentSetIndex!].reps,
//                weight: currentSegment!.sets[currentSetIndex!].practiceType.weight,
//                handedness: selectedPractice!.handedness(segment: currentSegment!, setIndex: currentSetIndex!),
//                type: currentSegment!.sets[currentSetIndex!].practiceType,
//                duration: Date.now.timeIntervalSince(setStart!),
//                lowHR: self.lowHR,
//                highHR: self.highHR
//            )
//        )
//    }
    
//    func advanceWorkout() {
//        guard let selectedPractice = selectedPractice,
//              currentSegment != nil,
//              currentSetIndex != nil
//        else {
//            return
//        }
//        addCompletedSet()
//        if currentSetIndex! + 1 < currentSegment!.sets.count {
//            currentSetIndex! += 1
//            return
//        }
//        if currentSegmentIndex! + 1 < selectedPractice.segments.count {
//            currentSegmentIndex! += 1
//            currentSetIndex = 0
//            return
//        }
//        endWorkout()
//    }
    
    
    
    // MARK: - Set Handling
    private func addActivity() {
        guard let session = session, let currentSegment = currentSegment, let currentExerciseIndex = currentExerciseIndex else { return }
        let currentExercise = currentSegment.sets[currentExerciseIndex]
        if let metadata = try? JSONEncoder().encode(currentExercise).base64EncodedString() {
            Logger.default.debug("\(metadata.description)")
            session.beginNewActivity(configuration: session.workoutConfiguration, date: Date(), metadata: [Exercise.metadataKey: metadata, PracticeSegmentNameMetaDataKey: currentSegment.name] as [String: Any])
        }
    }
    
    func startNextActivity() {
        guard let selectedPractice = selectedPractice else {
            return
        }
        // Workout is not started yet
        if currentExerciseIndex == nil, currentSegmentIndex == nil {
            currentExerciseIndex = 0
            currentSegmentIndex = 0
            addActivity()
        }
        else if currentExerciseIndex! + 1 < currentSegment!.sets.count {
            currentExerciseIndex! += 1
            addActivity()
        }
        else if currentSegmentIndex! + 1 < selectedPractice.segments.count {
            currentSegmentIndex! += 1
            currentExerciseIndex = 0
            addActivity()
        }
        else {
            endWorkout()
        }
    }
    
    var currentSegmentIndex: Int?
    var currentSegment: PracticeSegment?  {
        guard let selectedPractice = selectedPractice, let currentSegmentIndex = currentSegmentIndex else {
            return nil
        }
        return selectedPractice.segments[currentSegmentIndex]
    }
    
    var currentExerciseIndex: Int? //{

    
    var segmentDescription: String {
        currentSegment?.name ?? ""
    }
    
    
    var segmentSetCount: String {
        guard let currentSegment = currentSegment, let currentExerciseIndex = currentExerciseIndex else {
            return ""
        }
        if currentSegment.sets[currentExerciseIndex] == .rest { return "Rest" }
        let totalSets = currentSegment.sets.count(where: {$0 != .rest})
        let performedSets = currentSegment.sets.prefix(currentExerciseIndex + 1).count(where: {$0 != .rest})
        return "\(performedSets)/\(totalSets)"
    }
    
    var setDescription: String {
        guard let currentSegment = currentSegment, let currentExerciseIndex = currentExerciseIndex else {
            return ""
        }
        return currentSegment.sets[currentExerciseIndex].description
    }
    
    var setWeight: String {
        guard let currentSegment = currentSegment, let currentExerciseIndex = currentExerciseIndex else {
            return ""
        }
        if let weight = currentSegment.sets[currentExerciseIndex].weight {
            return "\(weight)Kg"
        }
        else { return "" }
    }
    
    
    // MARK: - Core Practice handling
    
    var selectedPractice: Practice? {
        didSet {
            guard selectedPractice != nil else { return }
            if let settings = selectedPractice?.settingsView {
                //DispatchQueue.main.async {
                    self.settingsView = settings
                    self.showingSettingsForPractice = true
                //}
                   
            }
            else {
                startCountdown()
            }
        }
    }
    
    
    func startPractice() {
        guard let selectedPractice = selectedPractice, selectedPractice.segments.count > 0 else { return }
        Logger.default.info("Starting practice: \(selectedPractice.name)")
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = selectedPractice.workoutType
        configuration.locationType = .indoor

        // Create the session and obtain the workout builder.
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            // Handle any exceptions.
            return
        }

        // Setup session and builder.
        session?.delegate = self
        builder?.delegate = self

        // Set the workout builder's data source.
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                     workoutConfiguration: configuration)

        // Start the workout session and begin data collection.
        let startDate = Date()
        session?.startActivity(with: startDate)
        
        startNextActivity()
        builder?.beginCollection(withStart: startDate) { (success, error) in
            if (error != nil) {
                Logger.default.error("\(error!.localizedDescription)")
            }
        }
    }
    
    
    
    
    // MARK: - Auth
    
    
    // Request authorization to access HealthKit.
    func requestAuthorization() {
        healthStore.requestAuthorization(toShare: HKObjectType.typesToShare, read: HKObjectType.typesToRead) { (success, error) in
            // Handle error.
        }
    }

    // MARK: - Session State Control

    // The app's workout state.
    var running = false

    func togglePause() {
        if running == true {
            self.pause()
        } else {
            resume()
        }
        
    }

    func pause() {
        WKInterfaceDevice.current().play(.stop)
        session?.pause()
        
    }

    func resume() {
        WKInterfaceDevice.current().play(.start)
        session?.resume()
        
    }

    func endWorkout() {
        session?.end()
        showingSummaryView = true
    }

    // MARK: - Workout Metrics
    var averageHeartRate: Double = 0
    var heartRate: Double = 0
    {
        didSet {
            Logger.default.info("Heart Rate: \(self.heartRate)")
        }
    }
    var activeEnergy: Double = 0
    var distance: Double = 0
    var workout: HKWorkout?

    nonisolated private func updateForStatistics(_ statistics: HKStatistics?) {
        Logger.default.debug("In update function")
        guard let statistics = statistics else { return }
        Logger.default.debug("Attempting to update")
        
        //DispatchQueue.main.async {
        Task { @MainActor in
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let energyUnit = HKUnit.kilocalorie()
                self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
            default:
                return
            }
        }
        //}
    }

    func resetWorkout() {
        //completedPractice = nil
        currentExerciseIndex = nil
        currentSegmentIndex = nil
        selectedPractice = nil
        builder = nil
        workout = nil
        session = nil
        activeEnergy = 0
        averageHeartRate = 0
        heartRate = 0
        distance = 0
    }
    
    func addWorkoutMetadata() async throws {
        Logger.default.info("Logging workout data")
        
        //let metadata = try JSONEncoder().encode(completedPractice)
        let otherMeta = [HKMetadataKeyWorkoutBrandName: selectedPractice?.rawValue ?? "Practice"]
        do {
            try await builder?.addMetadata(otherMeta)
//            let metaString = String(data: metadata, encoding: .utf8) ?? ""
//            try await builder?.addMetadata(["PracticeMeta": metaString])
        }
        catch (let error) {
            Logger.default.error("\(error.localizedDescription)")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension PracticeManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        Logger.default.debug("workoutSession didChangeTo \(toState.rawValue) -> \(fromState.rawValue)")
        Task { @MainActor in
            self.running = toState == .running
        }

        // Wait for the session to transition states before ending the builder.
        if toState == .ended {
            Task { @MainActor in
                do {
                    try await addWorkoutMetadata()
                    try await builder?.endCollection(at: date)
                    
                    let workout = try await builder?.finishWorkout()
                    WKInterfaceDevice.current().play(.success)
                    //DispatchQueue.main.async {
                        self.workout = workout
                    //}
                    let effortEstimator = EffortScoreEstimator()
                    if workout != nil {
                        let score = try await effortEstimator.estimateEffortScore(for: workout!, using: healthStore)
                        Logger.default.info("Effort Score: \(score)")
                        try await effortEstimator.saveEffortScoreToHealthKit(score: score, for: workout!, using: healthStore)
                    }
                }
                catch (let error) {
                    Logger.default.error("Error finishing workout: \(error)")
                }
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Logger.default.error("\(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension PracticeManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {

    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Logger.default.debug("In didCollectDataOf: \(collectedTypes)")
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                return // Nothing to do.
            }

            let statistics = workoutBuilder.statistics(for: quantityType)

            
            // Update the published values.
            updateForStatistics(statistics)
            
        }
    }
}


