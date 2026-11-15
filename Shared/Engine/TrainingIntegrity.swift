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
        return completion(for: workout, namesBySkill: namesBySkill(progressions: progressions))
    }

    private static func namesBySkill(progressions: [SkillProgression]) -> [Skill: Set<String>] {
        Dictionary(uniqueKeysWithValues: Skill.activeSkills.map { skill in
            let levels = progressions.filter { $0.skillName == skill.rawValue }.flatMap(\.levels).map(\.name)
            let routineNames = skill.practiceSteps(from: progressions)
                .filter { $0.exercise.category == .skillProgression }.map { $0.exercise.name }
            let legacyNames = skill == .pressHandstand ? SkillProgressions.legacyPressHandstandExerciseNames : []
            return (skill, Set(levels + routineNames + legacyNames + [skill.rawValue]))
        })
    }

    private static func completion(for workout: CompletedWorkout, namesBySkill: [Skill: Set<String>]) -> EveningCompletion? {
        guard workout.sessionType == .evening, workout.isMeaningfulTraining else { return nil }
        let trainedNames = Set(workout.exercises.filter { $0.sets.contains(where: \.hasCompletedActivity) }.map(\.exerciseName))
        let matches = namesBySkill.filter { !$0.value.isDisjoint(with: trainedNames) }.map(\.key)
        // Ambiguous or warm-up-only sessions must not guess a skill.
        guard matches.count == 1, let skill = matches.first else { return nil }
        return .init(id: workout.id, date: workout.endDate, skillName: skill.rawValue)
    }

    static func latest(workouts: [CompletedWorkout], entries: [SkillSessionEntry] = [],
                       progressions: [SkillProgression]) -> EveningCompletion? {
        let names = namesBySkill(progressions: progressions)
        let completedWorkouts = workouts.compactMap { completion(for: $0, namesBySkill: names) }
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

/// Small sync projection of recorded activity. The phone's workout store remains authoritative.
struct TrainingCompletion: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let sessionType: SessionType
    let cycleIndex: Int?
    let countsAsTraining: Bool
}

enum DailyPractice {
    static func ordered(_ history: [TrainingCompletion]) -> [TrainingCompletion] {
        history.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
    }

    static func nextIndex(history: [TrainingCompletion], on date: Date = .now) -> Int {
        guard let last = history.filter({ $0.date <= date && $0.cycleIndex != nil }).max(by: {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }), let index = last.cycleIndex else { return 0 }
        return (index + 1) % WorkoutData.mainSequence.count
    }

    static func requiresRest(history: [TrainingCompletion], on date: Date = .now,
                             calendar: Calendar = .current) -> Bool {
        let trainingDays = Set(history.filter { $0.countsAsTraining && $0.date <= date }
            .map { calendar.startOfDay(for: $0.date) })
        let today = calendar.startOfDay(for: date)
        return (1...6).allSatisfy { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return trainingDays.contains(day)
        }
    }

    static func isResting(history: [TrainingCompletion], restDays: [Date], on date: Date = .now,
                          calendar: Calendar = .current) -> Bool {
        requiresRest(history: history, on: date, calendar: calendar)
            || restDays.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    static func suggestedSession(history: [TrainingCompletion], restDays: [Date] = [],
                                  on date: Date = .now, calendar: Calendar = .current) -> SessionType? {
        guard !isResting(history: history, restDays: restDays, on: date, calendar: calendar) else { return nil }
        return WorkoutData.mainSequence[nextIndex(history: history, on: date)]
    }

    static func completion(for workout: CompletedWorkout, history: [TrainingCompletion],
                           progressions: [SkillProgression]) -> TrainingCompletion? {
        guard workout.isMeaningfulTraining else { return nil }
        let type = workout.sessionType
        let isSkill = EveningRotation.completion(for: workout, progressions: progressions) != nil
        guard WorkoutData.mainSequence.contains(type) || isSkill else { return nil }
        // Warm-up-only attempts neither advance the programme nor create training days.
        let names = Set(workout.exercises.filter { $0.sets.contains(where: \.hasCompletedActivity) }.map(\.exerciseName))
        if type == .morning {
            guard names.contains(Exercises.kbSwing.name) || names.contains(Exercises.tgu.name) else { return nil }
        } else if type == .strengthA || type == .strengthB {
            let mainNames = Set(WorkoutData.plan(for: type).steps.filter { $0.exercise.category != .warmup }.map { $0.exercise.name })
            guard !mainNames.isDisjoint(with: names) else { return nil }
        }
        let next = nextIndex(history: history, on: workout.endDate)
        let index = (0..<WorkoutData.mainSequence.count).map { (next + $0) % WorkoutData.mainSequence.count }
            .first { WorkoutData.mainSequence[$0] == type }
        return TrainingCompletion(id: workout.id, date: workout.endDate, sessionType: type,
                                  cycleIndex: index, countsAsTraining: type != .mobility)
    }

    static func history(workouts: [CompletedWorkout], progressions: [SkillProgression]) -> [TrainingCompletion] {
        var result: [TrainingCompletion] = []
        var latestMain: TrainingCompletion?
        var ids = Set<UUID>()
        for workout in workouts.sorted(by: { $0.endDate == $1.endDate ? $0.id.uuidString < $1.id.uuidString : $0.endDate < $1.endDate }) {
            guard ids.insert(workout.id).inserted,
                  let completion = completion(for: workout, history: latestMain.map { [$0] } ?? [], progressions: progressions) else { continue }
            result.append(completion)
            if completion.cycleIndex != nil { latestMain = completion }
        }
        // Keep the latest programme position even if it predates recent skill-only sessions.
        let recent = Array(result.suffix(120))
        if let main = result.last(where: { $0.cycleIndex != nil }), !recent.contains(where: { $0.id == main.id }) {
            return [main] + recent
        }
        return recent
    }

    static func permitsStart(plan: SessionPlan, history: [TrainingCompletion], restDays: [Date],
                              on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard isResting(history: history, restDays: restDays, on: date, calendar: calendar) else { return true }
        if plan.sessionType == .jointStretches { return true }
        // Full mobility includes bridge assistance; rest days offer gentle stretching instead.
        return plan.sessionType == .evening && plan.steps.allSatisfy { $0.exercise.category == .stretch }
    }
}
