//
//  WorkoutData.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//
import Foundation

public enum WorkoutData {
    
    public static let kbWeights: [Double] = [8, 16, 24, 28, 32, 40, 48]
    
    // MARK: - Morning: Simple & Sinister + Push/Pull
    
    public static var morningSteps: [WorkoutStep] {
        let warmupGroup = UUID()
        let pushPullGroup = UUID()
        
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
            
            // ── S&S: Swings — HR-gated rest ──────────────────────────
            WorkoutStep(
                exercise: Exercises.kbSwing,
                sets: 10,
                reps: 10,
                restSeconds: 60,
                isHRGated: true,
                hrRestThresholdBPM: 125
            ),
            
            // ── S&S: TGU — HR-gated rest ──────────────────────────────
            WorkoutStep(
                exercise: Exercises.tgu,
                sets: 10,
                reps: 1,
                restSeconds: 90,
                isHRGated: true,
                hrRestThresholdBPM: 125
            ),
            
            // ── Push/Pull Circuit: Push-Up + Pull-up───────────────
            WorkoutStep(
                exercise: Exercises.pushUp,
                sets: 3,
                reps: 10,
                restSeconds: 0,
                circuitGroupID: pushPullGroup
            ),
            WorkoutStep(
                exercise: Exercises.pullUp,
                sets: 3,
                reps: 5,
                restSeconds: 60,
                circuitGroupID: pushPullGroup
            ),
        ]
    }
    
    // MARK: - Evening Rotation
    
    public static func eveningSteps(
        rotationDay: Int,
        progressions: [SkillProgression]
    ) -> [WorkoutStep] {
        let skillIndex = rotationDay % Skill.activeSkills.count
        let skill = Skill.activeSkills[skillIndex]
        return skill.routine(from: progressions)
    }
    
    
    
}
