// HealthKitManager.swift — TrainingShared
// Handles HKWorkout session lifecycle and metric collection.
// The session itself runs on watchOS; the iOS side reads saved workouts.

import Foundation
import HealthKit

public enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case authorizationDenied
    case sessionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:         return "HealthKit is not available on this device."
        case .authorizationDenied:  return "HealthKit authorization was denied."
        case .sessionFailed(let m): return "Workout session error: \(m)"
        }
    }
}

public final class HealthKitManager: NSObject, Sendable {
    
    public static let shared = HealthKitManager()
    private let store = HKHealthStore()
    
    // Types we want to read & write
    private let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]
    
    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.vo2Max),
        HKQuantityType(.bodyMass),
        HKQuantityType(.respiratoryRate),
        HKCategoryType(.sleepAnalysis),
        HKCharacteristicType(.dateOfBirth),
        HKCharacteristicType(.biologicalSex)
    ]
    
    // MARK: - Authorization
    
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }
    
    // MARK: - Read completed workouts from HealthKit
    
    /// Fetch the most recent N workouts of activity type .functionalStrengthTraining
    public func fetchRecentWorkouts(limit: Int = 20) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForWorkouts(with: .functionalStrengthTraining)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }
    
    /// Fetch heart rate samples for a given workout
    public func fetchHeartRateSamples(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let hrType = HKQuantityType(.heartRate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }
    
    // MARK: - Convenience metrics
    
    public func averageHeartRate(from samples: [HKQuantitySample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let total = samples.map { $0.quantity.doubleValue(for: unit) }.reduce(0, +)
        return total / Double(samples.count)
    }
    
    public func peakHeartRate(from samples: [HKQuantitySample]) -> Double? {
        let unit = HKUnit.count().unitDivided(by: .minute())
        return samples.map { $0.quantity.doubleValue(for: unit) }.max()
    }
    
    // MARK: - Body Mass
    
    public func fetchLatestBodyMass() async throws -> Double? {
        try await fetchLatestQuantitySample(.bodyMass, unit: .gramUnit(with: .kilo))
    }
    
    public func fetchBodyMassHistory(days: Int = 90) async throws -> [(date: Date, kg: Double)] {
        let type = HKQuantityType(.bodyMass)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let unit = HKUnit.gramUnit(with: .kilo)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let result = (samples as? [HKQuantitySample] ?? []).map {
                    (date: $0.startDate, kg: $0.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }
    
    // MARK: - VO2Max
    
    public func fetchLatestVO2Max() async throws -> Double? {
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        return try await fetchLatestQuantitySample(.vo2Max, unit: unit)
    }
    
    public func fetchVO2MaxHistory(days: Int = 180) async throws -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.vo2Max)
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let result = (samples as? [HKQuantitySample] ?? []).map {
                    (date: $0.startDate, value: $0.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }
    
    private func fetchLatestQuantitySample(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let type = HKQuantityType(id)
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
    
    // MARK: - Biological characteristics
    
    /// Returns the user's age in years, computed from date of birth in HealthKit.
    /// Returns nil if not set or permission not granted.
    public func fetchAge() throws -> Int? {
        let components = try store.dateOfBirthComponents()
        guard let year = components.year else { return nil }
        let age = Calendar.current.component(.year, from: Date()) - year
        return age
    }
    
    public enum BiologicalSex: Sendable {
        case male, female, other, notSet
    }
    
    /// Returns the user's biological sex from HealthKit.
    public func fetchBiologicalSex() throws -> BiologicalSex {
        let hkSex = try store.biologicalSex().biologicalSex
        switch hkSex {
        case .male:             return .male
        case .female:           return .female
        case .other:            return .other
        case .notSet:           return .notSet
        @unknown default:       return .notSet
        }
    }
}

// MARK: - watchOS-only: Live Workout Session Manager
// This class is only compiled on watchOS. It manages the live HKWorkoutSession.

#if os(watchOS)
import WatchKit

@Observable
@MainActor
public final class WorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    
    public static let shared = WorkoutSessionManager()
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // Live metrics
    public var heartRate: Double = 0
    public var activeCalories: Double = 0
    public var elapsedSeconds: Int = 0
    public var isRunning: Bool = false
    public var isPaused: Bool = false
    
    private var timer: Timer?
    private var sessionStartDate: Date?
    
    // MARK: - Start
    
    public func startWorkout(activityType: HKWorkoutActivityType) async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = .indoor
        
        let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let newBuilder = newSession.associatedWorkoutBuilder()
        newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        
        newSession.delegate = self
        newBuilder.delegate = self
        
        self.session = newSession
        self.builder = newBuilder
        
        let startDate = Date()
        newSession.startActivity(with: startDate)
        try await newBuilder.beginCollection(at: startDate)
        
        sessionStartDate = startDate
        isRunning = true
        
        startTimer()
    }
    
    // MARK: - Pause / Resume
    
    public func pauseWorkout() {
        session?.pause()
        isPaused = true
        timer?.invalidate()
    }
    
    public func resumeWorkout() {
        session?.resume()
        isPaused = false
        startTimer()
    }
    
    // MARK: - End
    
    /// Ends the workout, saves to HealthKit, and returns the saved HKWorkout UUID.
    public func endWorkout() async throws -> UUID? {
        guard let session, let builder else { return nil }
        
        let endDate = Date()
        session.end()
        try await builder.endCollection(at: endDate)
        
        let workout = try await builder.finishWorkout()
        stopTimer()
        isRunning = false
        isPaused = false
        
        return workout?.uuid
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - HKWorkoutSessionDelegate
    
    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}
    
    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {}
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    
    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            Task { @MainActor [weak self] in
                guard let self else { return }
                let stats = workoutBuilder.statistics(for: quantityType)
                
                switch quantityType {
                case HKQuantityType(.heartRate):
                    let hrUnit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = stats?.mostRecentQuantity()?.doubleValue(for: hrUnit) ?? self.heartRate
                    
                case HKQuantityType(.activeEnergyBurned):
                    let calUnit = HKUnit.kilocalorie()
                    self.activeCalories = stats?.sumQuantity()?.doubleValue(for: calUnit) ?? self.activeCalories
                    
                default:
                    break
                }
            }
        }
    }
}
#endif
