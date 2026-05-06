//
//  TrainingSchemaV1.swift
//  Practice
//
//  Created by Steve Bryce on 04/05/2026.
//

import SwiftData
import Foundation

enum TrainingSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { allModels }
    
    private static var allModels: [any PersistentModel.Type] {[
        WorkoutRecord.self,
        ExerciseRecord.self,
        SetRecord.self,
        SkillProgressionRecord.self,
        SkillSessionRecord.self,
        SkillSetRecord.self,
        KettlebellWeightRecord.self,
        AppSettings.self,
        RecoveryScoreRecord.self,
        RestDayRecord.self,
    ]}
    
    // MARK: - Workout Records
    
    @Model
    public final class WorkoutRecord {
        public var id: UUID = UUID()
        public var sessionTypeRaw: String = ""
        public var startDate: Date = Date()
        public var endDate: Date = Date()
        public var activeCalories: Double? = nil
        public var averageHeartRate: Double? = nil
        public var peakHeartRate: Double? = nil
        public var hkWorkoutUUID: UUID? = nil
        public var notes: String? = nil
        
        @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.workout)
        public var exercises: [ExerciseRecord]? = nil
        
        public var sessionType: SessionType {
            SessionType(rawValue: sessionTypeRaw) ?? .morning
        }
        
        public var durationMinutes: Int {
            Int(endDate.timeIntervalSince(startDate) / 60)
        }
        
        public var exercisesSorted: [ExerciseRecord] {
            (exercises ?? []).sorted { $0.sortIndex < $1.sortIndex }
        }
        
        public init(from workout: CompletedWorkout) {
            self.id               = workout.id
            self.sessionTypeRaw   = workout.sessionType.rawValue
            self.startDate        = workout.startDate
            self.endDate          = workout.endDate
            self.activeCalories   = workout.activeCalories
            self.averageHeartRate = workout.averageHeartRate
            self.peakHeartRate    = workout.peakHeartRate
            self.hkWorkoutUUID    = workout.hkWorkoutUUID
            self.exercises = workout.exercises.enumerated().map { idx, ex in
                let exRecord = ExerciseRecord(from: ex, sortIndex: idx)
                exRecord.sets = ex.sets.enumerated().map { sIdx, s in
                    SetRecord(from: s, sortIndex: sIdx)
                }
                exRecord.workout = self
                return exRecord
            }
        }
        
        public func toCompletedWorkout() -> CompletedWorkout {
            CompletedWorkout(
                id: id,
                sessionType: sessionType,
                startDate: startDate,
                endDate: endDate,
                exercises: exercisesSorted.map { $0.toCompletedExercise() },
                activeCalories: activeCalories,
                averageHeartRate: averageHeartRate,
                peakHeartRate: peakHeartRate,
                hkWorkoutUUID: hkWorkoutUUID
            )
        }
    }
    
    @Model
    public final class ExerciseRecord {
        public var id: UUID = UUID()
        public var exerciseID: UUID = UUID()
        public var exerciseName: String = ""
        public var skillLevel: Int? = nil
        public var sortIndex: Int = 0          // preserves exercise order
        
        // Inverse relationship back to workout (required by CloudKit)
        public var workout: WorkoutRecord? = nil
        
        @Relationship(deleteRule: .cascade, inverse: \SetRecord.exercise)
        public var sets: [SetRecord]? = nil
        
        public var setsSorted: [SetRecord] {
            (sets ?? []).sorted { $0.sortIndex < $1.sortIndex }
        }
        
        public init(from ex: CompletedExercise, sortIndex: Int = 0) {
            self.id           = ex.id
            self.exerciseID   = ex.exerciseID
            self.exerciseName = ex.exerciseName
            self.skillLevel   = ex.skillLevel
            self.sortIndex    = sortIndex
        }
        
        public func toCompletedExercise() -> CompletedExercise {
            CompletedExercise(
                id: id,
                exerciseID: exerciseID,
                exerciseName: exerciseName,
                sets: setsSorted.map { $0.toCompletedSet() },
                skillLevel: skillLevel
            )
        }
    }
    
    @Model
    public final class SetRecord {
        public var id: UUID = UUID()
        public var reps: Int? = nil
        public var durationSeconds: Int? = nil
        public var difficultyRaw: Int = 3
        public var tguSideRaw: String? = nil
        public var sortIndex: Int = 0
        
        public var exercise: ExerciseRecord? = nil
        
        public var feltDifficulty: DifficultyRating {
            DifficultyRating(rawValue: difficultyRaw) ?? .moderate
        }
        
        public var tguSide: TGUSide? {
            guard let raw = tguSideRaw else { return nil }
            return TGUSide(rawValue: raw)
        }
        
        public init(from s: CompletedSet, sortIndex: Int = 0) {
            self.id              = s.id
            self.reps            = s.reps
            self.durationSeconds = s.durationSeconds
            self.difficultyRaw   = s.feltDifficulty.rawValue
            self.tguSideRaw      = s.tguSide?.rawValue
            self.sortIndex       = sortIndex
        }
        
        public func toCompletedSet() -> CompletedSet {
            CompletedSet(
                id: id, reps: reps, durationSeconds: durationSeconds,
                feltDifficulty: feltDifficulty, tguSide: tguSide
            )
        }
    }
    
    // MARK: - Skill Progression
    
    @Model
    public final class SkillProgressionRecord {
        public var id: UUID = UUID()
        public var skillName: String = ""
        public var currentLevel: Int = 1
        public var levelsData: Data = Data()   // JSON-encoded [SkillLevel]
        
        public var levels: [SkillLevel] {
            get { (try? JSONDecoder().decode([SkillLevel].self, from: levelsData)) ?? [] }
            set { levelsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
        }
        
        public var currentSkillLevel: SkillLevel? { levels.first { $0.level == currentLevel } }
        public var nextSkillLevel: SkillLevel?     { levels.first { $0.level == currentLevel + 1 } }
        
        public init(from progression: SkillProgression) {
            self.id           = progression.id
            self.skillName    = progression.skillName
            self.currentLevel = progression.currentLevel
            self.levelsData   = (try? JSONEncoder().encode(progression.levels)) ?? Data()
        }
        
        public func toSkillProgression() -> SkillProgression {
            SkillProgression(id: id, skillName: skillName, levels: levels, currentLevel: currentLevel)
        }
    }
    
    // MARK: - Skill Session
    
    @Model
    public final class SkillSessionRecord {
        public var id: UUID = UUID()
        public var date: Date = Date()
        public var skillProgressionID: UUID = UUID()
        public var level: Int = 1
        
        @Relationship(deleteRule: .cascade, inverse: \SkillSetRecord.session)
        public var sets: [SkillSetRecord]? = nil
        
        public var averageDifficulty: Double {
            let s = sets ?? []
            guard !s.isEmpty else { return 3 }
            return Double(s.map(\.difficultyRaw).reduce(0, +)) / Double(s.count)
        }
        
        public var totalReps: Int     { (sets ?? []).compactMap(\.reps).reduce(0, +) }
        public var totalDuration: Int { (sets ?? []).compactMap(\.durationSeconds).reduce(0, +) }
        
        public init(from entry: SkillSessionEntry) {
            self.id                 = entry.id
            self.date               = entry.date
            self.skillProgressionID = entry.skillProgressionID
            self.level              = entry.level
            self.sets = entry.sets.enumerated().map { idx, s in
                let r = SkillSetRecord(from: s, sortIndex: idx)
                r.session = self
                return r
            }
        }
        
        public func toSkillSessionEntry() -> SkillSessionEntry {
            SkillSessionEntry(
                id: id, date: date,
                skillProgressionID: skillProgressionID,
                level: level,
                sets: (sets ?? []).map { $0.toCompletedSet() }
            )
        }
    }
    
    /// Separate set model for skill sessions (avoids ambiguity with workout SetRecord)
    @Model
    public final class SkillSetRecord {
        public var id: UUID = UUID()
        public var reps: Int? = nil
        public var durationSeconds: Int? = nil
        public var difficultyRaw: Int = 3
        public var sortIndex: Int = 0
        
        public var session: SkillSessionRecord? = nil
        
        public var feltDifficulty: DifficultyRating {
            DifficultyRating(rawValue: difficultyRaw) ?? .moderate
        }
        
        public init(from s: CompletedSet, sortIndex: Int = 0) {
            self.id              = s.id
            self.reps            = s.reps
            self.durationSeconds = s.durationSeconds
            self.difficultyRaw   = s.feltDifficulty.rawValue
            self.sortIndex       = sortIndex
        }
        
        public func toCompletedSet() -> CompletedSet {
            CompletedSet(id: id, reps: reps, durationSeconds: durationSeconds, feltDifficulty: feltDifficulty)
        }
    }
    
    // MARK: - Kettlebell Weight Record
    
    @Model
    public final class KettlebellWeightRecord {
        public var id: UUID = UUID()
        public var date: Date = Date()
        public var exerciseTypeRaw: String = ""
        public var weightKg: Double = 16
        public var sets: Int = 1
        public var reps: Int = 10
        public var notes: String? = nil
        
        public var exerciseType: KettlebellExerciseType {
            KettlebellExerciseType(rawValue: exerciseTypeRaw) ?? .swing
        }
        
        public init(id: UUID = UUID(), date: Date = .now,
                    exerciseType: KettlebellExerciseType,
                    weightKg: Double, sets: Int, reps: Int, notes: String? = nil) {
            self.id              = id
            self.date            = date
            self.exerciseTypeRaw = exerciseType.rawValue
            self.weightKg        = weightKg
            self.sets            = sets
            self.reps            = reps
            self.notes           = notes
        }
    }
    
    // MARK: - App Settings
    
    @Model
    public final class AppSettings {
        public var id: UUID = UUID()
        public var targetSwingWeightKg: Double = 32
        public var targetTGUWeightKg: Double = 32
        public var eveningRotationDay: Int = 0
        public var notificationsEnabled: Bool = true
        public var morningReminderHour: Int = 5
        public var morningReminderMinute: Int = 00
        public var eveningReminderHour: Int = 18
        public var eveningReminderMinute: Int = 30
        
        public static var menSimple:   (swing: Double, tgu: Double) { (32, 32) }
        public static var womenSimple: (swing: Double, tgu: Double) { (24, 16) }
        
        public init() {}
    }
    
    // MARK: - Recovery Score Record
    
    @Model
    public final class RecoveryScoreRecord {
        public var id: UUID = UUID()
        public var date: Date = Date()
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
        
        public var readinessLabel: String {
            switch overallScore {
            case 85...:   return "Excellent"
            case 70..<85: return "Good"
            case 50..<70: return "Moderate"
            case 30..<50: return "Poor"
            default:      return "Very Low"
            }
        }
        
        public init(id: UUID = UUID(), date: Date, overallScore: Double) {
            self.id           = id
            self.date         = date
            self.overallScore = overallScore
        }
    }
    
    // MARK: - Rest Day Record
    
    @Model
    public final class RestDayRecord {
        public var id: UUID = UUID()
        public var date: Date = Calendar.current.startOfDay(for: .now)
        
        public init(id: UUID = UUID(), date: Date = Calendar.current.startOfDay(for: .now)) {
            self.id   = id
            self.date = date
        }
    }
    
}
