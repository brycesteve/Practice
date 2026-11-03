import Foundation
import SwiftData
import Testing
@testable import Practice

@Suite("Training persistence integrity")
@MainActor
struct TrainingPersistenceIntegrityTests {
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
