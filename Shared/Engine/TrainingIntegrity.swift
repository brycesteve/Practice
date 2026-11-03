import Foundation

/// A completed Practice workout requires an explicitly logged repetition or timed activity.
/// Viewing a plan, elapsed time, heart rate and incidental calories alone are not completion.
extension CompletedSet {
    var hasCompletedActivity: Bool { (reps ?? 0) > 0 || (durationSeconds ?? 0) > 0 }
}

extension CompletedWorkout {
    var hasCompletedActivity: Bool {
        endDate > startDate && exercises.contains { $0.sets.contains(where: \.hasCompletedActivity) }
    }

    /// Exact fingerprint of the old development schema bootstrap, not a general short-workout filter.
    var isLegacySchemaSeed: Bool {
        endDate.timeIntervalSince(startDate) < 1 && activeCalories == 100 && averageHeartRate == 100
            && !exercises.isEmpty && exercises.allSatisfy { $0.exerciseName == "Test" }
    }

    var isMeaningfulTraining: Bool { hasCompletedActivity && !isLegacySchemaSeed }
}

/// Sync/cache projection of durable completed-skill evidence; no additional SwiftData state.
struct EveningCompletion: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let skillName: String
}

enum EveningRotation {
    static func normalized(_ index: Int) -> Int {
        let count = Skill.activeSkills.count
        return (index % count + count) % count
    }

    static func nextIndex(after completion: EveningCompletion?, fallback: Int) -> Int {
        guard let completion,
              let index = Skill.activeSkills.firstIndex(where: { $0.rawValue == completion.skillName }) else {
            return normalized(fallback)
        }
        return (index + 1) % Skill.activeSkills.count
    }

    static func completion(for workout: CompletedWorkout, progressions: [SkillProgression]) -> EveningCompletion? {
        guard workout.sessionType == .evening, workout.isMeaningfulTraining else { return nil }
        let trainedNames = Set(workout.exercises.filter { $0.sets.contains(where: \.hasCompletedActivity) }.map(\.exerciseName))
        let matches = Skill.activeSkills.filter { skill in
            let levels = progressions.filter { $0.skillName == skill.rawValue }.flatMap(\.levels).map(\.name)
            let routineNames = skill.routine(from: progressions)
                .filter { $0.exercise.category == .skillProgression }.map { $0.exercise.name }
            let legacyNames = skill == .pressHandstand
                ? SkillProgressions.legacyPressHandstandExerciseNames
                : []
            return !trainedNames.isDisjoint(with: Set(levels + routineNames + legacyNames + [skill.rawValue]))
        }
        // Ambiguous or warm-up-only sessions must not guess a skill.
        guard matches.count == 1, let skill = matches.first else { return nil }
        return .init(id: workout.id, date: workout.endDate, skillName: skill.rawValue)
    }

    static func latest(workouts: [CompletedWorkout], entries: [SkillSessionEntry] = [],
                       progressions: [SkillProgression]) -> EveningCompletion? {
        let completedWorkouts = workouts.compactMap { completion(for: $0, progressions: progressions) }
        // Legacy skill entries are emitted only on workout completion, and identify the actual skill.
        let completedEntries: [EveningCompletion] = entries.compactMap { entry in
            guard entry.sets.contains(where: \.hasCompletedActivity),
                  let progression = progressions.first(where: { $0.id == entry.skillProgressionID }),
                  Skill.activeSkills.contains(where: { $0.rawValue == progression.skillName }) else { return nil }
            return .init(id: entry.id, date: entry.date, skillName: progression.skillName)
        }
        return (completedWorkouts + completedEntries).max { $0.date < $1.date }
    }
}

/// The existing readiness weighting, shared with cache validation. No workout records are inputs.
enum RecoveryAggregation {
    static func score(_ values: [Double?]) -> Double {
        let weights = [0.30, 0.20, 0.20, 0.15, 0.05, 0.10]
        let pairs = zip(values, weights).compactMap { value, weight -> (Double, Double)? in
            guard let value, value.isFinite, (0...100).contains(value) else { return nil }
            return (value, weight)
        }
        let total = pairs.map { $0.1 }.reduce(0, +)
        return total == 0 ? 50 : pairs.map { $0.0 * ($0.1 / total) }.reduce(0, +).rounded()
    }

    static func isConsistent(_ record: RecoveryDataDTO) -> Bool {
        let values = [record.hrvScore, record.restingHRScore, record.sleepDurationScore,
                      record.sleepQualityScore, record.respiratoryRateScore, record.trainingLoadScore]
        guard record.overallScore.isFinite,
              values.compactMap({ $0 }).allSatisfy({ $0.isFinite && (0...100).contains($0) }) else { return false }
        return abs(record.overallScore - score(values)) < 0.51
    }
}

/// Hosted unit tests must not open CloudKit stores or activate external services.
enum PracticeExecution {
    static var isTesting: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["PracticeIsolatedTests"] == "1"
            || NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
#else
        false
#endif
    }
}
