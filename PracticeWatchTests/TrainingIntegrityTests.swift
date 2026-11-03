import Foundation
import Testing
@testable import PracticeWatch_Watch_App

@Suite("Training integrity")
struct TrainingIntegrityTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private var progressions: [SkillProgression] { SkillProgressions.defaultSkillProgressions }

    private func workout(_ skill: Skill = .rings, logged: Bool = true, offset: Double = 0) -> CompletedWorkout {
        let name = progressions.first { $0.skillName == skill.rawValue }?.levels.first?.name ?? skill.rawValue
        return .init(sessionType: .evening, startDate: date.addingTimeInterval(offset - 600),
            endDate: date.addingTimeInterval(offset), exercises: [
                .init(exerciseID: UUID(), exerciseName: name,
                    sets: logged ? [.init(reps: 3)] : [])
            ])
    }

    @Test func testHostIsIsolated() {
        #expect(PracticeExecution.isTesting)
        #expect(ProcessInfo.processInfo.environment["PracticeIsolatedTests"] == "1")
    }

    @Test func elapsedTimeCaloriesAndHeartRateAreNotCompletion() {
        var value = workout(logged: false)
        value.activeCalories = 100
        value.averageHeartRate = 90
        value.hkWorkoutUUID = UUID()
        #expect(!value.isMeaningfulTraining)
        value.exercises[0].sets = [.init(reps: 0, durationSeconds: 0)]
        #expect(!value.hasCompletedActivity)
        value.exercises[0].sets = [.init(durationSeconds: 15)]
        #expect(value.isMeaningfulTraining) // Real partial/timed sessions remain valid.
    }

    @Test func ringCompletionAdvancesToHandstandDespiteStaleCounter() throws {
        let last = try #require(EveningRotation.completion(for: workout(), progressions: progressions))
        let index = EveningRotation.nextIndex(after: last, fallback: 1)
        #expect(Skill.activeSkills[index] == .handstand)
    }

    @Test func emptyAndWarmupOnlyEveningsCannotAdvanceRotation() {
        #expect(EveningRotation.completion(for: workout(logged: false), progressions: progressions) == nil)
        var warmup = workout()
        warmup.exercises[0].exerciseName = "Wrist Stretches"
        #expect(EveningRotation.completion(for: warmup, progressions: progressions) == nil)
        let last = EveningRotation.latest(workouts: [workout(), workout(.planche, logged: false, offset: 900), warmup],
            progressions: progressions)
        #expect(last?.skillName == Skill.rings.rawValue)
    }

    @Test func manualCompletionAndOutOfOrderDeliveryUseActualLatestSkill() {
        let last = EveningRotation.latest(workouts: [workout(.frontLever, offset: 800), workout(.rings)],
            progressions: progressions)
        #expect(Skill.activeSkills[EveningRotation.nextIndex(after: last, fallback: 0)] == .compression)
        #expect(EveningRotation.normalized(-1) == Skill.activeSkills.count - 1)
    }

    @Test func legacySkillEntryIsDurableEvidenceButEmptyEntriesAreNot() throws {
        let values = progressions
        let rings = try #require(values.first { $0.skillName == Skill.rings.rawValue })
        let entry = SkillSessionEntry(date: date, skillProgressionID: rings.id, level: 1, sets: [.init(durationSeconds: 20)])
        let empty = SkillSessionEntry(date: date.addingTimeInterval(100), skillProgressionID: rings.id, level: 1, sets: [])
        let last = EveningRotation.latest(workouts: [], entries: [empty, entry], progressions: values)
        #expect(last?.id == entry.id)
        #expect(Skill.activeSkills[EveningRotation.nextIndex(after: last, fallback: 1)] == .handstand)
    }

    @Test func completionSyncRemainsBackwardsCompatible() throws {
        let legacy = try JSONDecoder().decode(WCSyncPayload.self, from: Data("{}".utf8))
        #expect(legacy.lastEveningCompletion == nil)
        var payload = WCSyncPayload()
        payload.lastEveningCompletion = EveningRotation.completion(for: workout(), progressions: progressions)
        let restored = try JSONDecoder().decode(WCSyncPayload.self, from: JSONEncoder().encode(payload))
        #expect(restored.lastEveningCompletion == payload.lastEveningCompletion)
    }

    @Test func artificialHundredIsNotAConsistentRecoveryCache() {
        var seed = RecoveryDataDTO()
        seed.overallScore = 100
        seed.hrvScore = 18
        seed.restingHRScore = 20
        seed.sleepDurationScore = 10
        seed.sleepQualityScore = 10
        seed.respiratoryRateScore = 20
        seed.trainingLoadScore = 30
        #expect(!RecoveryAggregation.isConsistent(seed))
        #expect(RecoveryAggregation.score([18, 20, 10, 10, 20, 30]) == 17)
        seed.overallScore = 17
        #expect(RecoveryAggregation.isConsistent(seed))
    }

    @Test func missingMetricsRemainNeutralAndLegitimateHundredRemainsPossible() {
        #expect(RecoveryAggregation.score([nil, nil, nil, nil, nil, nil]) == 50)
        var value = RecoveryDataDTO()
        value.overallScore = 100
        value.sleepDurationScore = 100
        #expect(RecoveryAggregation.isConsistent(value))
        value.hrvScore = .nan
        #expect(!RecoveryAggregation.isConsistent(value))
    }
}
