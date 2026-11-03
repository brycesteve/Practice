//
//  WorkoutData.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//
import Foundation

public enum WorkoutData {
    
    public static let kbWeights: [Double] = [8, 16, 24, 28, 32, 40, 48]
    
    public static let strengthWeights: [Double] = [4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, 32, 40, 48]

    // MARK: - Simple & Sinister
    
    public static var morningSteps: [WorkoutStep] {
        let warmupGroup = UUID()
        
        return [
            // ── Warmup Circuit (3 rounds, one exercise at a time) ────
            WorkoutStep(
                exercise: Exercises.gobletSquat,
                sets: 3,
                reps: 5,
                restSeconds: 15,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercises.hipRaise,
                sets: 3,
                reps: 5,
                restSeconds: 15,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercises.halo,
                sets: 3,
                reps: 5,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            
            // ── S&S: Swings — athlete-declared recovery ───────────────
            WorkoutStep(
                exercise: Exercises.kbSwing,
                sets: 10,
                reps: 10,
                restSeconds: 60,
                notes: "Rest until recovered, usually 90 seconds or longer. Your usual ~115 bpm is an additional guide; press Ready when recovered.",
                isHRGated: true
            ),
            
            // ── S&S: TGU — athlete-declared recovery ─────────────────
            WorkoutStep(
                exercise: Exercises.tgu,
                sets: 10,
                reps: 1,
                restSeconds: 90,
                notes: "Rest until recovered. No time limit or mandatory heart-rate threshold.",
                isHRGated: true
            ),
            
        ]
    }
    
    // Calendar weekday: Sunday = 1. Inject date/calendar for deterministic tests.
    public static func scheduledSession(on date: Date = .now, calendar: Calendar = .current) -> SessionType? {
        scheduledSession(weekday: calendar.component(.weekday, from: date))
    }

    public static func scheduledSession(weekday: Int) -> SessionType? {
        switch weekday {
        case 2, 4, 6: return .morning
        case 3: return .strengthA
        case 5: return .mobility
        case 7: return .strengthB
        default: return nil
        }
    }

    public static let strengthGuidance = "Leave 2–3 reps in reserve. Rest until recovered. When all sets are consistently comfortable with clean technique, increase difficulty or reps manually; keep the number of sets unchanged."

    private static func strengthStep(_ exercise: Exercise, sets: Int, reps: Int,
                                     loadKey: String? = nil, upperReps: Int? = nil,
                                     circuit: UUID? = nil) -> WorkoutStep {
        WorkoutStep(exercise: exercise, sets: sets, reps: reps, notes: strengthGuidance,
                    circuitGroupID: circuit, isHRGated: true,
                    repUpperBound: upperReps, strengthLoadKey: loadKey)
    }

    public static var strengthASteps: [WorkoutStep] {
        [strengthStep(Exercises.ringPushUp, sets: 3, reps: 6),
         strengthStep(Exercises.ringRow, sets: 3, reps: 6),
         strengthStep(Exercises.strengthGobletSquat, sets: 2, reps: 5, loadKey: "gobletSquat"),
         strengthStep(Exercises.hangingKneeRaise, sets: 2, reps: 8)]
    }

    public static var strengthBSteps: [WorkoutStep] {
        let sides = UUID()
        return [
            strengthStep(Exercises.cleanPressLeft, sets: 3, reps: 5, loadKey: "cleanPress", circuit: sides),
            strengthStep(Exercises.cleanPressRight, sets: 3, reps: 5, loadKey: "cleanPress", circuit: sides),
            strengthStep(Exercises.strengthPullUp, sets: 3, reps: 3, upperReps: 5),
            strengthStep(Exercises.ringPushUp, sets: 2, reps: 6),
            strengthStep(Exercises.hangingKneeRaise, sets: 2, reps: 8)
        ]
    }

    public static var mobilitySteps: [WorkoutStep] {
        // Thursday-only additions fill ankle and upper-back rotation gaps.
        Skill.commonStretches() + [
            WorkoutStep(exercise: Exercises.ankleRocks, sets: 2, durationSeconds: 30, restSeconds: 15),
            WorkoutStep(exercise: Exercises.thoracicRotation, sets: 2, durationSeconds: 30, restSeconds: 15)
        ]
    }

    public static func plan(for type: SessionType, rotationDay: Int = 0,
                            progressions: [SkillProgression] = []) -> SessionPlan {
        let steps: [WorkoutStep]
        let minutes: Int
        switch type {
        case .morning: steps = morningSteps; minutes = 45
        case .strengthA: steps = strengthASteps; minutes = 25
        case .strengthB: steps = strengthBSteps; minutes = 30
        case .mobility: steps = mobilitySteps; minutes = 15
        case .jointStretches:
            steps = [WorkoutStep(exercise: Exercises.jointStretches, sets: 1, restSeconds: 0)]
            minutes = 0 // Open duration: no target or countdown.
        case .evening: steps = eveningSteps(rotationDay: rotationDay, progressions: progressions); minutes = 30
        }
        return SessionPlan(sessionType: type, steps: steps, estimatedDurationMinutes: minutes)
    }

    // MARK: - Evening Rotation
    
    public static func eveningSteps(
        rotationDay: Int,
        progressions: [SkillProgression]
    ) -> [WorkoutStep] {
        let skillIndex = EveningRotation.normalized(rotationDay)
        let skill = Skill.activeSkills[skillIndex]
        return skill.routine(from: progressions)
    }
    
    
    
}
