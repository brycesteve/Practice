import Foundation
import SwiftData
import Testing
@testable import Practice

@Suite("Training persistence integrity")
@MainActor
struct TrainingPersistenceIntegrityTests {
    @Test func lightweightWorkoutCompletionMatchesTheTransferModel() throws {
        let store = try container()
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        for sets in [[], [.init(reps: 0, durationSeconds: 0)], [.init(reps: 3)], [.init(durationSeconds: 30)]] as [[CompletedSet]] {
            for duration in [0.0, 0.5, 60.0] {
                for legacy in [false, true] {
                    let workout = CompletedWorkout(sessionType: .evening, startDate: start,
                        endDate: start.addingTimeInterval(duration), exercises: [
                            .init(exerciseID: UUID(), exerciseName: legacy ? "Test" : "Recorded exercise", sets: sets)
                        ], activeCalories: legacy ? 100 : nil, averageHeartRate: legacy ? 100 : nil)
                    let record = WorkoutRecord(from: workout)
                    store.mainContext.insert(record)
                    #expect(record.isMeaningfulTraining == workout.isMeaningfulTraining)
                }
            }
        }
    }

    private func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(CurrentSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test func promotionCannotInsertIntoAUsersContainer() throws {
        let store = try container()
        #expect(throws: CloudKitSchemaPromotionEngine.PromotionError.self) {
            try CloudKitSchemaPromotionEngine.run(container: store)
        }
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WorkoutRecord>()) == 0)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WaistMeasurementRecord>()) == 0)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<RecoveryScoreRecord>()) == 0)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<AppSettings>()) == 0)
    }

    @Test func emptyImportCannotPersistOrResetReadiness() throws {
        let store = try container()
        let recovery = RecoveryScoreRecord(date: .now, overallScore: 69)
        recovery.hrvScore = 69
        store.mainContext.insert(recovery)
        try store.mainContext.save()
        let empty = CompletedWorkout(sessionType: .evening, startDate: .now.addingTimeInterval(-60),
            endDate: .now, exercises: [], activeCalories: 0)
        #expect(try !TrainingHistoryIntegrity.insertWorkout(empty, into: store))
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WorkoutRecord>()) == 0)
        let preserved = try #require(store.mainContext.fetch(FetchDescriptor<RecoveryScoreRecord>()).first)
        #expect(preserved.id == recovery.id)
        #expect(preserved.overallScore == 69)
        #expect(preserved.isConsistentCache)
    }

    @Test func realPartialWorkoutPersistsOnceWithItsSets() throws {
        let store = try container()
        let workout = CompletedWorkout(sessionType: .evening, startDate: .now.addingTimeInterval(-60),
            endDate: .now, exercises: [.init(exerciseID: UUID(), exerciseName: "Ring Skills", sets: [.init(reps: 3)])])
        #expect(try TrainingHistoryIntegrity.insertWorkout(workout, into: store))
        #expect(try !TrainingHistoryIntegrity.insertWorkout(workout, into: store))
        let record = try #require(store.mainContext.fetch(FetchDescriptor<WorkoutRecord>()).first)
        #expect(record.isMeaningfulTraining)
        #expect(record.exercisesSorted.first?.setsSorted.count == 1)
        #expect(TrainingHistoryIntegrity.latestEvening(in: store.mainContext)?.skillName == Skill.rings.rawValue)
    }

    @Test func rollingPracticeUsesDurableWorkoutsWithoutChangingLoggedMetrics() throws {
        let store = try container()
        let end = Date(timeIntervalSinceReferenceDate: 800_000)
        let start = end.addingTimeInterval(-600)
        let logged = CompletedSet(reps: 10, feltDifficulty: .easy, weightKg: 24,
            startedAt: start, endedAt: start.addingTimeInterval(20), preSetHeartRate: 110,
            peakHeartRate: 150, recoveryHeartRate: 115, recoveryStartedAt: start.addingTimeInterval(120))
        let workout = CompletedWorkout(sessionType: .morning, startDate: start, endDate: end,
            exercises: [.init(exerciseID: Exercises.kbSwing.id, exerciseName: Exercises.kbSwing.name, sets: [logged])],
            activeCalories: 90, averageHeartRate: 125, peakHeartRate: 150)
        #expect(try TrainingHistoryIntegrity.insertWorkout(workout, into: store))
        #expect(try !TrainingHistoryIntegrity.insertWorkout(workout, into: store))
        let record = try #require(store.mainContext.fetch(FetchDescriptor<WorkoutRecord>()).first)
        let restored = record.toCompletedWorkout()
        let set = try #require(restored.exercises.first?.sets.first)
        #expect(set.weightKg == logged.weightKg)
        #expect(set.preSetHeartRate == logged.preSetHeartRate)
        #expect(set.peakHeartRate == logged.peakHeartRate)
        #expect(set.recoveryHeartRate == logged.recoveryHeartRate)
        #expect(set.startedAt == logged.startedAt)
        #expect(set.endedAt == logged.endedAt)
        #expect(set.recoveryStartedAt == logged.recoveryStartedAt)
        #expect(restored.averageHeartRate == workout.averageHeartRate)
        let history = DailyPractice.history(workouts: [restored], progressions: [])
        #expect(DailyPractice.suggestedSession(history: history, on: end.addingTimeInterval(86400)) == .strengthA)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WorkoutRecord>()) == 1)
    }

    @Test(arguments: [0.0, -1, Double.nan, Double.infinity])
    func rejectsInvalidWaistBeforeInsertion(_ cm: Double) throws {
        let store = try container()
        #expect(throws: (any Error).self) {
            try BodyMeasurementStore.insertWaist(date: .now, circumferenceCm: cm, heightCm: nil, into: store.mainContext)
        }
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WaistMeasurementRecord>()) == 0)
    }

    @Test func legacyZeroWaistIsIgnoredWithoutDeletingIt() throws {
        let store = try container()
        let valid = try WaistMeasurementRecord(date: .now.addingTimeInterval(-100), circumferenceCm: 85, heightCm: 172)
        let legacy = try WaistMeasurementRecord(circumferenceCm: 85)
        legacy.circumferenceCm = 0 // Simulate the old schema seed only in this memory store.
        store.mainContext.insert(valid)
        store.mainContext.insert(legacy)
        try store.mainContext.save()
        #expect(try BodyMeasurementStore.latestValidWaist(in: store.mainContext, at: .now)?.id == valid.id)
        let display = BodyStatsSnapshot(measurements: [], waists: [legacy, valid],
            healthWeight: [], vo2: [], currentProfile: .init())
        #expect(display.series[.waist]?.count == 1)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WaistMeasurementRecord>()) == 2)
        #expect(legacy.circumferenceCm == 0)
    }

    @Test func bodyImportWithAbsentWaistDoesNotCreateWaistRecord() throws {
        let store = try container()
        let scale = try #require(ScaleIdentifier(companyID: 0xA0AC, macAddress: "A0:91:5B:35:E2:A8"))
        let raw = RawBodyMeasurement(weightKg: 67.8, impedanceOhms: 529, scale: scale)
        try BodyMeasurementStore.insert(raw, into: store)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WaistMeasurementRecord>()) == 0)
        #expect(try store.mainContext.fetch(FetchDescriptor<BodyMeasurementRecord>()).first?.profile.waistCm == nil)
    }

    @Test func legacyDiagnosticSeedsCannotSupplyReadinessOrTrainingEvidence() throws {
        let recovery = try #require(RecoveryScoreRecord.makeSeed() as? RecoveryScoreRecord)
        let workout = try #require(WorkoutRecord.makeSeed() as? WorkoutRecord)
        #expect(!recovery.isConsistentCache)
        #expect(!workout.isMeaningfulTraining)
    }
}

@Suite("Trial workout persistence")
@MainActor
struct TrialWorkoutPersistenceTests {
    @Test func replacementStretchAndMobilitySequencesPersistInOrderIncludingRepeatedMovements() throws {
        let store = try ModelContainer(for: Schema(CurrentSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let start = Date(timeIntervalSinceReferenceDate: 10000)
        for (type, steps) in [(SessionType.evening, WorkoutData.eveningStretchSteps + WorkoutData.barHangSteps),
                              (.mobility, WorkoutData.mobilitySteps)] {
            let exercises = steps.map { step in
                CompletedExercise(exerciseID: step.exercise.id, exerciseName: step.exercise.name,
                    sets: (0..<step.sets).map { _ in
                        CompletedSet(durationSeconds: step.durationSeconds, startedAt: start,
                            endedAt: start.addingTimeInterval(Double(step.durationSeconds ?? 0)))
                    })
            }
            let workout = CompletedWorkout(sessionType: type, startDate: start,
                endDate: start.addingTimeInterval(1800), exercises: exercises)
            let transferred = try JSONDecoder().decode(CompletedWorkout.self, from: JSONEncoder().encode(workout))
            #expect(try TrainingHistoryIntegrity.insertWorkout(transferred, into: store))
            #expect(try !TrainingHistoryIntegrity.insertWorkout(transferred, into: store))
            let id = workout.id
            let record = try #require(store.mainContext.fetch(FetchDescriptor<WorkoutRecord>(
                predicate: #Predicate { $0.id == id })).first)
            let restored = record.toCompletedWorkout()
            #expect(restored.exercises.map(\.exerciseName) == exercises.map(\.exerciseName))
            #expect(restored.exercises.map(\.exerciseID) == exercises.map(\.exerciseID))
            #expect(restored.exercises.map { $0.sets.count } == steps.map(\.sets))
            #expect(restored.exercises.map { $0.sets.first?.durationSeconds } == steps.map(\.durationSeconds))
            #expect(restored.exercises.allSatisfy { $0.sets.first?.startedAt == start })
        }
    }

    @Test func strengthWarmupAndWorkingRingSetsPersistSeparately() throws {
        let store = try ModelContainer(for: Schema(CurrentSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let steps = WorkoutData.strengthASteps
        let preparation = try #require(steps.first { $0.exercise.name == "Easy Ring Push-Up" })
        let working = try #require(steps.first { $0.exercise.name == "Ring Push-Up" })
        let workout = CompletedWorkout(sessionType: .strengthA, startDate: .now.addingTimeInterval(-300),
            endDate: .now, exercises: [
                .init(exerciseID: preparation.exercise.id, exerciseName: preparation.exercise.name, sets: [.init(reps: 5)]),
                .init(exerciseID: working.exercise.id, exerciseName: working.exercise.name,
                      sets: [.init(reps: 6, feltDifficulty: .easy)])
            ])
        let transferred = try JSONDecoder().decode(CompletedWorkout.self, from: JSONEncoder().encode(workout))
        #expect(try TrainingHistoryIntegrity.insertWorkout(transferred, into: store))
        #expect(try !TrainingHistoryIntegrity.insertWorkout(transferred, into: store))
        let record = try #require(store.mainContext.fetch(FetchDescriptor<WorkoutRecord>()).first)
        let restored = record.toCompletedWorkout()
        #expect(restored.exercises.map(\.exerciseName) == workout.exercises.map(\.exerciseName))
        #expect(restored.exercises.map(\.exerciseID) == workout.exercises.map(\.exerciseID))
        #expect(restored.exercises.map { $0.sets.first?.reps } == [5, 6])
    }

    @Test func storedSetsRetainLoadAndAllHeartRateTimingFields() throws {
        let store = try ModelContainer(for: Schema(CurrentSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let start = Date(timeIntervalSinceReferenceDate: 10000)
        let set = CompletedSet(reps: 5, feltDifficulty: .easy, weightKg: 8,
            startedAt: start, endedAt: start.addingTimeInterval(10), preSetHeartRate: 110,
            peakHeartRate: 135, recoveryHeartRate: 115, recoveryStartedAt: start.addingTimeInterval(100))
        for type in [SessionType.morning, .evening, .strengthA, .strengthB, .mobility, .jointStretches] {
            let workout = CompletedWorkout(sessionType: type, startDate: start, endDate: start.addingTimeInterval(120),
                exercises: [.init(exerciseID: UUID(), exerciseName: "Recorded exercise", sets: [set])], averageHeartRate: 120)
            #expect(try TrainingHistoryIntegrity.insertWorkout(workout, into: store))
            let id = workout.id
            let record = try #require(store.mainContext.fetch(FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.id == id })).first)
            let restored = record.toCompletedWorkout()
            let restoredSet = try #require(restored.exercises.first?.sets.first)
            #expect(restored.sessionType == type)
            #expect(restored.averageHeartRate == 120)
            #expect(restoredSet.id == set.id)
            #expect(restoredSet.weightKg == 8)
            #expect(restoredSet.reps == 5)
            #expect(restoredSet.feltDifficulty == .easy)
            #expect(restoredSet.startedAt == set.startedAt)
            #expect(restoredSet.endedAt == set.endedAt)
            #expect(restoredSet.preSetHeartRate == 110)
            #expect(restoredSet.peakHeartRate == 135)
            #expect(restoredSet.recoveryHeartRate == 115)
            #expect(restoredSet.recoveryStartedAt == set.recoveryStartedAt)
        }
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WorkoutRecord>()) == 6)
    }
}
