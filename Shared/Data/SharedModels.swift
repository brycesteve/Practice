// Models.swift — TrainingShared
// Swift 6, Sendable-conformant value types throughout

import Foundation
import HealthKit

// MARK: - Session Type

public enum SessionType: String, Codable, CaseIterable, Sendable {
    case morning = "Morning"
    case evening = "Evening"
    
    public var displayName: String { rawValue }
    public var emoji: String {
        switch self {
        case .morning: return "☀️"
        case .evening: return "🌙"
        }
    }
    public var workoutActivityType: HKWorkoutActivityType {
        // Both are functional strength training
        return .functionalStrengthTraining
    }
}

// MARK: - Exercise

public enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case kettlebell, calisthenics, stretch, skillProgression, warmup
}

public enum KettlebellExerciseType: String, Codable, CaseIterable, Sendable {
    case swing = "One-Arm Swing"
    case tgu   = "Turkish Get-Up"
    
    public var shortName: String {
        switch self { case .swing: return "Swing"; case .tgu: return "TGU" }
    }
    public var icon: String {
        switch self {
        case .swing: return "figure.strengthtraining.functional"
        case .tgu:   return "figure.mind.and.body"
        }
    }
}


public enum SetType: String, Codable, Sendable {
    case reps          // e.g. "10 reps"
    case timed         // e.g. "30 seconds hold"
    case repRange      // e.g. "3–5 reps"
    case amrap         // as many reps as possible
}

public struct Exercise: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var category: ExerciseCategory
    public var setType: SetType
    public var defaultSets: Int
    public var defaultReps: Int?       // nil for timed
    public var defaultDuration: Int?   // seconds, nil for reps
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        setType: SetType = .reps,
        defaultSets: Int = 3,
        defaultReps: Int? = nil,
        defaultDuration: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.setType = setType
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultDuration = defaultDuration
        self.notes = notes
    }
}

// MARK: - Workout Session (plan)

public struct WorkoutStep: Identifiable, Codable, Sendable {
    public let id: UUID
    public var exercise: Exercise
    public var sets: Int
    public var reps: Int?
    public var durationSeconds: Int?
    public var restSeconds: Int
    public var notes: String?
    
    /// Non-nil UUID groups this step into a circuit/superset with other steps sharing the same ID.
    /// Steps in the same circuit are cycled round-by-round rather than all-sets-then-next.
    public var circuitGroupID: UUID?
    
    /// If true, rest after this set is HR-gated: user sees live BPM and a "Ready" button
    /// that unlocks once HR drops below `hrRestThresholdBPM`.
    public var isHRGated: Bool
    
    /// BPM threshold below which the "Ready" button unlocks. Default 130.
    public var hrRestThresholdBPM: Double
    
    public var displayTarget: String {
        if let reps { return "\(sets) × \(reps) reps" }
        if let dur  { return "\(sets) × \(dur)s" }
        return "\(sets) sets"
    }
    
    private var dur: Int? { durationSeconds }
    
    public init(
        id: UUID = UUID(),
        exercise: Exercise,
        sets: Int,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        restSeconds: Int = 60,
        notes: String? = nil,
        circuitGroupID: UUID? = nil,
        isHRGated: Bool = false,
        hrRestThresholdBPM: Double = 130
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.notes = notes
        self.circuitGroupID = circuitGroupID
        self.isHRGated = isHRGated
        self.hrRestThresholdBPM = hrRestThresholdBPM
    }
}

public struct SessionPlan: Identifiable, Codable, Sendable {
    public let id: UUID
    public var sessionType: SessionType
    public var steps: [WorkoutStep]
    public var estimatedDurationMinutes: Int
    
    public init(id: UUID = UUID(), sessionType: SessionType, steps: [WorkoutStep], estimatedDurationMinutes: Int) {
        self.id = id
        self.sessionType = sessionType
        self.steps = steps
        self.estimatedDurationMinutes = estimatedDurationMinutes
    }
}

// MARK: - Completed Workout

public struct CompletedSet: Identifiable, Codable, Sendable {
    public let id: UUID
    public var reps: Int?
    public var durationSeconds: Int?
    public var feltDifficulty: DifficultyRating  // 1–5
    public var tguSide: TGUSide?                 // non-nil for TGU sets only
    
    public init(id: UUID = UUID(), reps: Int? = nil, durationSeconds: Int? = nil,
                feltDifficulty: DifficultyRating = .moderate, tguSide: TGUSide? = nil) {
        self.id = id
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.feltDifficulty = feltDifficulty
        self.tguSide = tguSide
    }
}

public enum DifficultyRating: Int, Codable, CaseIterable, Sendable {
    case veryEasy = 1, easy = 2, moderate = 3, hard = 4, maxEffort = 5
    
    public var label: String {
        switch self {
        case .veryEasy:  return "Very Easy"
        case .easy:      return "Easy"
        case .moderate:  return "Moderate"
        case .hard:      return "Hard"
        case .maxEffort: return "Max Effort"
        }
    }
    
    public var emoji: String {
        switch self {
        case .veryEasy:  return "😴"
        case .easy:      return "🙂"
        case .moderate:  return "💪"
        case .hard:      return "😤"
        case .maxEffort: return "🔥"
        }
    }
}

public struct CompletedExercise: Identifiable, Codable, Sendable {
    public let id: UUID
    public var exerciseID: UUID
    public var exerciseName: String
    public var sets: [CompletedSet]
    public var skillLevel: Int?   // non-nil for skill progressions
    
    public init(id: UUID = UUID(), exerciseID: UUID, exerciseName: String, sets: [CompletedSet], skillLevel: Int? = nil) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
        self.skillLevel = skillLevel
    }
}

public struct CompletedWorkout: Identifiable, Codable, Sendable {
    public let id: UUID
    public var sessionType: SessionType
    public var startDate: Date
    public var endDate: Date
    public var exercises: [CompletedExercise]
    
    // HealthKit data (filled in after HKWorkout is saved)
    public var activeCalories: Double?
    public var averageHeartRate: Double?
    public var peakHeartRate: Double?
    public var hkWorkoutUUID: UUID?
    
    public var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
    
    public init(
        id: UUID = UUID(),
        sessionType: SessionType,
        startDate: Date,
        endDate: Date,
        exercises: [CompletedExercise],
        activeCalories: Double? = nil,
        averageHeartRate: Double? = nil,
        peakHeartRate: Double? = nil,
        hkWorkoutUUID: UUID? = nil
    ) {
        self.id = id
        self.sessionType = sessionType
        self.startDate = startDate
        self.endDate = endDate
        self.exercises = exercises
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.peakHeartRate = peakHeartRate
        self.hkWorkoutUUID = hkWorkoutUUID
    }
}

// MARK: - Skill Progression

public struct SkillLevel: Identifiable, Codable, Sendable {
    public let id: UUID
    public var level: Int               // 1 = beginner
    public var name: String             // e.g. "Tuck Planche"
    public var details: String
    public var targetReps: Int?
    public var targetDurationSeconds: Int?
    public var advanceCriteria: AdvanceCriteria
    public var dateAchieved: Date?      // set when user advances past this level
    
    public init(
        id: UUID = UUID(),
        level: Int,
        name: String,
        details: String,
        targetReps: Int? = nil,
        targetDurationSeconds: Int? = nil,
        advanceCriteria: AdvanceCriteria,
        dateAchieved: Date? = nil
    ) {
        self.id = id
        self.level = level
        self.name = name
        self.details = details
        self.targetReps = targetReps
        self.targetDurationSeconds = targetDurationSeconds
        self.advanceCriteria = advanceCriteria
        self.dateAchieved = dateAchieved
    }
}

public enum TGUSide: String, Codable, CaseIterable, Sendable {
    case left  = "L"
    case right = "R"
    
    public var next: TGUSide { self == .left ? .right : .left }
    public var label: String { rawValue }
}

/// Criteria that must be met (across N sessions) to advance to the next level.
public struct AdvanceCriteria: Codable, Sendable {
    /// Number of consecutive (or recent) sessions meeting the target
    public var consecutiveSessions: Int
    /// Max average difficulty to consider "mastered" (e.g. ≤ easy)
    public var maxAverageDifficulty: Double
    /// Minimum reps OR seconds that must be achieved each session
    public var minReps: Int?
    public var minDurationSeconds: Int?
    
    public init(consecutiveSessions: Int = 3, maxAverageDifficulty: Double = 2.5, minReps: Int? = nil, minDurationSeconds: Int? = nil) {
        self.consecutiveSessions = consecutiveSessions
        self.maxAverageDifficulty = maxAverageDifficulty
        self.minReps = minReps
        self.minDurationSeconds = minDurationSeconds
    }
}

public struct RecoveryDataDTO: Codable, Sendable {
    public var overallScore: Double = 0
    public var hrvScore: Double? = nil
    public var restingHRScore: Double? = nil
    public var sleepDurationScore: Double? = nil
    public var sleepQualityScore: Double? = nil
    public var respiratoryRateScore: Double? = nil
    public var trainingLoadScore: Double? = nil
    public var hrv: Double? = nil
    public var restingHR: Double? = nil
    public var sleepHours: Double? = nil
    public var respiratoryRate: Double? = nil
    public var activeEnergyYesterday: Double? = nil
    
    
}

// MARK: - Sendable transfer type for kettlebell entries
// KettlebellWeightRecord is a SwiftData @Model and therefore not Sendable.
// We pass this value type across actor boundaries instead, and construct
// the @Model object only once safely on the main actor in the delegate.

public struct KettlebellEntryTransfer: Sendable {
    public let id: UUID
    public let date: Date
    public let exerciseType: KettlebellExerciseType
    public let weightKg: Double
    public let sets: Int
    public let reps: Int
    
    public init(id: UUID = UUID(), date: Date = .now,
                exerciseType: KettlebellExerciseType,
                weightKg: Double, sets: Int, reps: Int) {
        self.id          = id
        self.date        = date
        self.exerciseType = exerciseType
        self.weightKg    = weightKg
        self.sets        = sets
        self.reps        = reps
    }
    
    
}

public struct SkillProgression: Identifiable, Codable, Sendable {
    public let id: UUID
    public var skillName: String   // e.g. "Planche", "Handstand", "Ring Skills"
    public var levels: [SkillLevel]
    public var currentLevel: Int   // index into levels
    
    public var currentSkillLevel: SkillLevel? {
        levels.first { $0.level == currentLevel }
    }
    
    public var nextSkillLevel: SkillLevel? {
        levels.first { $0.level == currentLevel + 1 }
    }
    
    public init(id: UUID = UUID(), skillName: String, levels: [SkillLevel], currentLevel: Int = 1) {
        self.id = id
        self.skillName = skillName
        self.levels = levels
        self.currentLevel = currentLevel
    }
}

/// Per-skill session history entry used by the progression engine
public struct SkillSessionEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public var date: Date
    public var skillProgressionID: UUID
    public var level: Int
    public var sets: [CompletedSet]
    
    public var averageDifficulty: Double {
        guard !sets.isEmpty else { return 3 }
        return Double(sets.map(\.feltDifficulty.rawValue).reduce(0, +)) / Double(sets.count)
    }
    
    public var totalReps: Int {
        sets.compactMap(\.reps).reduce(0, +)
    }
    
    public var totalDuration: Int {
        sets.compactMap(\.durationSeconds).reduce(0, +)
    }
    
    public init(id: UUID = UUID(), date: Date = .now, skillProgressionID: UUID, level: Int, sets: [CompletedSet]) {
        self.id = id
        self.date = date
        self.skillProgressionID = skillProgressionID
        self.level = level
        self.sets = sets
    }
}
