import Foundation
import SwiftData

extension WorkoutRecord {
    var isMeaningfulTraining: Bool {
        let exercises = exercises ?? []
        let isLegacySeed = endDate.timeIntervalSince(startDate) < 1 && activeCalories == 100 && averageHeartRate == 100
            && !exercises.isEmpty && exercises.allSatisfy { $0.exerciseName == "Test" }
        return endDate > startDate && !isLegacySeed && exercises.contains {
            ($0.sets ?? []).contains { ($0.reps ?? 0) > 0 || ($0.durationSeconds ?? 0) > 0 }
        }
    }
}

extension RecoveryScoreRecord {
    var isConsistentCache: Bool { RecoveryAggregation.isConsistent(toDTO()) }
}

@MainActor
enum TrainingHistoryIntegrity {
    static func latestEvening(in context: ModelContext) -> EveningCompletion? {
        let evening = SessionType.evening.rawValue
        let workouts = (try? context.fetch(FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.sessionTypeRaw == evening }))) ?? []
        let entries = (try? context.fetch(FetchDescriptor<SkillSessionRecord>())) ?? []
        let progressions = (try? context.fetch(FetchDescriptor<SkillProgressionRecord>())) ?? []
        return EveningRotation.latest(workouts: workouts.map { $0.toCompletedWorkout() },
            entries: entries.map { $0.toSkillSessionEntry() },
            progressions: progressions.map { $0.toSkillProgression() } + SkillProgressions.defaultSkillProgressions)
    }

    /// Dedicated context: invalid imports cannot autosave or roll back unrelated user edits.
    @discardableResult
    static func insertWorkout(_ workout: CompletedWorkout, into container: ModelContainer) throws -> Bool {
        guard workout.isMeaningfulTraining else { return false }
        let context = ModelContext(container)
        let id = workout.id
        guard try context.fetch(FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.id == id })).isEmpty else { return false }
        context.insert(WorkoutRecord(from: workout))
        try context.save()
        return true
    }
}
