import Foundation
import SwiftData

extension WorkoutRecord {
    var isMeaningfulTraining: Bool { toCompletedWorkout().isMeaningfulTraining }
}

extension RecoveryScoreRecord {
    var isConsistentCache: Bool { RecoveryAggregation.isConsistent(toDTO()) }
}

@MainActor
enum TrainingHistoryIntegrity {
    static func latestEvening(in context: ModelContext) -> EveningCompletion? {
        let workouts = (try? context.fetch(FetchDescriptor<WorkoutRecord>())) ?? []
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
