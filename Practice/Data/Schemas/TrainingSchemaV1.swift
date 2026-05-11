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
        ConditioningScoreRecord.self
    ]}
    
    // MARK: - Workout Records
    
    @Model
    public final class WorkoutRecord: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            let w = Self.init(
                from: CompletedWorkout(
                    sessionType: .morning,
                    startDate: Date(),
                    endDate: Date(),
                    exercises: [
                        CompletedExercise(
                            exerciseID: UUID(),
                            exerciseName: "Test",
                            sets: [
                                CompletedSet(
                                    reps: 1,
                                    durationSeconds: 30,
                                    feltDifficulty: .easy,
                                    tguSide: .left
                                )
                            ]
                        )
                    ],
                    activeCalories: 100,
                    averageHeartRate: 100,
                    peakHeartRate: 120,
                    hkWorkoutUUID: UUID()
                )
            )
            w.notes = ""
            return w
        }
    }
    
    
    @Model
    public final class ExerciseRecord: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            let w = WorkoutRecord(
                from: CompletedWorkout(
                    sessionType: .morning,
                    startDate: Date(),
                    endDate: Date(),
                    exercises: [
                        CompletedExercise(
                            exerciseID: UUID(),
                            exerciseName: "Test",
                            sets: [
                                CompletedSet(
                                    reps: 1,
                                    durationSeconds: 30,
                                    feltDifficulty: .easy,
                                    tguSide: .left
                                )
                            ]
                        )
                    ],
                    activeCalories: 100,
                    averageHeartRate: 100,
                    hkWorkoutUUID: UUID()
                )
            )
            let ex = ExerciseRecord(
                from: CompletedExercise(exerciseID: UUID(), exerciseName: "Test", sets: [
                    CompletedSet(
                        id: UUID(),
                        reps: 2,
                        durationSeconds: 30,
                        feltDifficulty: .easy,
                        tguSide: .left
                    )
                ], skillLevel: 1)
            )
            ex.sortIndex = 1
            ex.workout = w
            return ex
        }
    }
    
    @Model
    public final class SetRecord: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            let ex = ExerciseRecord(
                from: CompletedExercise(exerciseID: UUID(), exerciseName: "Test", sets: [
                    CompletedSet(
                        id: UUID(),
                        reps: 2,
                        durationSeconds: 30,
                        feltDifficulty: .easy,
                        tguSide: .left
                    )
                ], skillLevel: 1)
            )
            let set = SetRecord(from: CompletedSet(
                id: UUID(),
                reps: 2,
                durationSeconds: 30,
                feltDifficulty: .easy,
                tguSide: .left
            ), sortIndex: 1)
            set.exercise = ex
            return set
            
        }
    }
    
    // MARK: - Skill Progression
    
    @Model
    public final class SkillProgressionRecord: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            SkillProgressionRecord(from: SkillProgressions.handstand)
        }
    }
    
    // MARK: - Skill Session
    
    @Model
    public final class SkillSessionRecord: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            SkillSessionRecord(
                from: SkillSessionEntry(skillProgressionID: UUID(), level: 1, sets: [
                    CompletedSet(
                        id: UUID(),
                        durationSeconds: 30,
                        feltDifficulty: .easy
                    )
                ])
            )
        }
    }
    
    /// Separate set model for skill sessions (avoids ambiguity with workout SetRecord)
    @Model
    public final class SkillSetRecord: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            let sess = SkillSessionRecord(
                from: SkillSessionEntry(skillProgressionID: UUID(), level: 1, sets: [
                    CompletedSet(
                        id: UUID(),
                        durationSeconds: 30,
                        feltDifficulty: .easy
                    )
                ])
            )
            let set = SkillSetRecord(from: CompletedSet(
                id: UUID(),
                reps: 3,
                durationSeconds: 30,
                feltDifficulty: .easy
            ), sortIndex: 0)
            set.session = sess
            return set
        }
    }
    
    // MARK: - Kettlebell Weight Record
    
    @Model
    public final class KettlebellWeightRecord: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            KettlebellWeightRecord(
                id: UUID(),
                date: Date(),
                exerciseType: .swing,
                weightKg: 16,
                sets: 10,
                reps: 10,
                notes: ""
            )
        }
    }
    
    // MARK: - App Settings
    
    @Model
    public final class AppSettings: CloudKitSchemaSeedable {
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
        
        static func makeSeed() -> any PersistentModel {
            AppSettings()
        }
    }
    
    // MARK: - Recovery Score Record
    
    @Model
    public final class RecoveryScoreRecord: CloudKitSchemaSeedable {
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
        
        func toDTO() -> RecoveryDataDTO {
            var dto = RecoveryDataDTO()
            dto.overallScore = self.overallScore
            dto.hrvScore = self.hrvScore
            dto.restingHRScore = self.restingHRScore
            dto.sleepDurationScore = self.sleepDurationScore
            dto.sleepQualityScore = self.sleepQualityScore
            dto.respiratoryRateScore = self.respiratoryRateScore
            dto.trainingLoadScore = self.trainingLoadScore
            dto.hrv = self.hrv
            dto.restingHR = self.restingHR
            dto.sleepHours = self.sleepHours
            dto.respiratoryRate = self.respiratoryRate
            dto.activeEnergyYesterday = self.activeEnergyYesterday
            return dto
        }
        
        static func makeSeed() -> any PersistentModel {
            let r = RecoveryScoreRecord(date: Date(), overallScore: 100)
            r.hrvScore = 18
            r.restingHRScore = 20
            r.sleepDurationScore = 10
            r.sleepQualityScore = 10
            r.respiratoryRateScore = 20
            r.trainingLoadScore = 30
            r.hrv = 14
            r.restingHR = 80
            r.sleepHours = 8
            r.respiratoryRate = 15
            r.activeEnergyYesterday = 120
            return r
        }
    }
    
    // MARK: - Rest Day Record
    
    @Model
    public final class RestDayRecord: CloudKitSchemaSeedable {
        public var id: UUID = UUID()
        public var date: Date = Calendar.current.startOfDay(for: .now)
        
        public init(id: UUID = UUID(), date: Date = Calendar.current.startOfDay(for: .now)) {
            self.id   = id
            self.date = date
        }
        
        static func makeSeed() -> any PersistentModel {
            RestDayRecord()
        }
    }
    
    // MARK: - Conditioning Score Record (updated weekly)
    
    @Model
    public final class ConditioningScoreRecord: CloudKitSchemaSeedable {
        public var id: UUID = UUID()
        public var date: Date = Date()                  // start of week
        public var overallScore: Double = 0             // 0–100
        public var hrRecoveryScore: Double? = nil       // component scores
        public var rhrTrendScore: Double? = nil
        public var hrvTrendScore: Double? = nil
        public var vo2TrendScore: Double? = nil
        public var consistencyScore: Double? = nil
        public var strengthRatioScore: Double? = nil
        public var hrRecoveryRate: Double? = nil        // raw: bpm drop in 60s
        public var rhrSlope: Double? = nil              // raw: bpm/day (negative = improving)
        public var hrvSlope: Double? = nil              // raw: ms/day (positive = improving)
        public var vo2Slope: Double? = nil              // raw: ml/kg/min per day
        public var latestKBRatio: Double? = nil         // swing PB kg / bodyweight kg
        
        public var trendLabel: String {
            switch overallScore {
            case 75...:   return "Strong upward trend"
            case 55..<75: return "Gradual improvement"
            case 45..<55: return "Holding steady"
            case 25..<45: return "Slight decline"
            default:      return "Needs attention"
            }
        }
        
        public var trendEmoji: String {
            switch overallScore {
            case 70...:   return "📈"
            case 50..<70: return "➡️"
            default:      return "📉"
            }
        }
        
        public init(id: UUID = UUID(), date: Date = .now, overallScore: Double) {
            self.id           = id
            self.date         = date
            self.overallScore = overallScore
        }
        
        static func makeSeed() -> any PersistentModel {
            let c = ConditioningScoreRecord(id: UUID(), overallScore: 10)
            c.date = .now
            c.hrRecoveryScore = 10
            c.rhrTrendScore = 10
            c.hrvTrendScore = 10
            c.vo2TrendScore = 20
            c.consistencyScore = 10
            c.strengthRatioScore = 10
            c.hrRecoveryRate = 10
            c.rhrSlope = 1
            c.hrvSlope = 1
            c.vo2Slope = 1
            c.latestKBRatio = 2
            return c
        }
    }
}
