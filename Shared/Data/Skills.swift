

import Foundation
import SwiftUI



public enum Skill: String, RawRepresentable, CaseIterable {
    case planche = "Planche"
    case handstand = "Handstand"
    case rings = "Ring Skills"
    
    static var activeSkills: [Skill] {
        [.planche, .handstand, .rings]
    }
    
    var icon: String {
        switch self {
        case .planche:     return "figure.gymnastics"
        case .handstand:   return "figure.stand"
        case .rings: return "circle.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .planche:     return .purple
        case .handstand:   return .blue
        case .rings: return .orange
        }
    }
    
    
    func routine(from progressions: [SkillProgression]) -> [WorkoutStep] {
        let currentLevel = progressions.first {
            $0.skillName == self.rawValue
        }?.currentSkillLevel
        
        let routine = { switch self {
        case .planche: return plancheRoutine(currentLevel: currentLevel)
        case .handstand: return handstandRoutine(currentLevel: currentLevel)
        case .rings: return ringsRoutine(currentLevel: currentLevel)
        }}()
        
        return routine + coreStretches()
    }
    
    private func coreStretches() -> [WorkoutStep] {
        [
            WorkoutStep(
                exercise: Exercises.ninetyNinety,
                sets: 4,
                durationSeconds: 30,
                restSeconds: 30
            ),
            WorkoutStep(
                exercise: Exercises.qlStraddle,
                sets: 4,
                durationSeconds: 30,
                restSeconds: 30
            ),
            WorkoutStep(
                exercise: Exercises.hamstringStretch,
                sets: 4,
                durationSeconds: 30,
                restSeconds: 30
            ),
            WorkoutStep(
                exercise: Exercises.hipFlexorStretch,
                sets: 4,
                durationSeconds: 30,
                restSeconds: 30
            ),
            WorkoutStep(
                exercise: Exercises.barHang,
                sets: 2,
                durationSeconds: 60,
                restSeconds: 60
            )
            
        ]
    }
    
    private func plancheRoutine(currentLevel: SkillLevel?) -> [WorkoutStep] {
        
        let warmupGroup = UUID()
        
        return [
            WorkoutStep(
                exercise: Exercises.wristStretches,
                sets: 2,
                durationSeconds: 30,
                restSeconds: 10,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercises.scapPushUp,
                sets: 2,
                reps: 10,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: currentLevel?.name ?? "Planche Lean",
                    category: .skillProgression,
                    setType: .timed,
                    defaultSets: 5,
                    defaultDuration: currentLevel?.targetDurationSeconds ?? 30,
                    notes: currentLevel?.details ?? "Lean forward past hands"
                ),
                sets: 5,
                durationSeconds: currentLevel?.targetDurationSeconds ?? 30,
                restSeconds: 120,
                notes: "Log actual hold time and rate effort."
            ),
            
            WorkoutStep(
                exercise: Exercises.psuedoPlanchePush,
                sets: 3,
                reps: 8,
                restSeconds: 90
            ),
            WorkoutStep(
                exercise: Exercises.plancheLeanHold,
                sets: 3,
                durationSeconds: 20,
                restSeconds: 60
            ),
        ] + plancheStretches()
    }
    
    private func plancheStretches() -> [WorkoutStep] {
        [
            WorkoutStep(
                exercise: Exercise(
                    name: "Chest & Shoulder Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 45,
                    notes: "Each side"
                ),
                sets: 2,
                durationSeconds: 45,
                restSeconds: 15
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Wrist Flexor Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Fingers pointing back"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 15
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Prone Thoracic Extension",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Lay prone, prop on elbows"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 15
            ),
        ]
    }
    
    private func handstandRoutine(currentLevel: SkillLevel?)
    -> [WorkoutStep]
    {
        let warmupGroup = UUID()
        
        return [
            WorkoutStep(
                exercise: Exercise(
                    name: "Wrist Warm-Up",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Circles, extensions, prayer stretches"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 10,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Shoulder Shrugs in Downdog",
                    category: .warmup,
                    setType: .reps,
                    defaultSets: 2,
                    defaultReps: 10,
                    notes: "Elevate and depress scapulae"
                ),
                sets: 2,
                reps: 10,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: currentLevel?.name ?? "Wall Handstand Hold",
                    category: .skillProgression,
                    setType: .timed,
                    defaultSets: 5,
                    defaultDuration: currentLevel?.targetDurationSeconds ?? 30,
                    notes: currentLevel?.details
                    ?? "Hold against wall, chest to wall"
                ),
                sets: 5,
                durationSeconds: currentLevel?.targetDurationSeconds ?? 30,
                restSeconds: 90,
                notes: "Log your best hold time each attempt."
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: "Handstand Walk / Shoulder Taps",
                    category: .calisthenics,
                    setType: .timed,
                    defaultSets: 3,
                    defaultDuration: 30,
                    notes: "Controlled movement or taps"
                ),
                sets: 3,
                durationSeconds: 30,
                restSeconds: 60
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Pike Compression Hold",
                    category: .calisthenics,
                    setType: .timed,
                    defaultSets: 3,
                    defaultDuration: 20,
                    notes: "Builds body tension for HS"
                ),
                sets: 3,
                durationSeconds: 20,
                restSeconds: 60
            ),
        ] + handstandStretches()
    }
    
    private func handstandStretches() -> [WorkoutStep] {
        [
            WorkoutStep(
                exercise: Exercise(
                    name: "Overhead Shoulder Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 45,
                    notes: "Each arm"
                ),
                sets: 2,
                durationSeconds: 45,
                restSeconds: 15
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Bridge Hold",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 3,
                    defaultDuration: 30,
                    notes: "Full thoracic extension"
                ),
                sets: 3,
                durationSeconds: 30,
                restSeconds: 30
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Pancake Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 3,
                    defaultDuration: 45,
                    notes: "Straddle forward fold"
                ),
                sets: 3,
                durationSeconds: 45,
                restSeconds: 15
            ),
        ]
    }
    
    private func ringsRoutine(currentLevel: SkillLevel?)
    -> [WorkoutStep]
    {
        let warmupGroup = UUID()
        
        return [
            WorkoutStep(
                exercise: Exercise(
                    name: "Ring Support Hold",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 20,
                    notes: "Rings turned out. Lock arms."
                ),
                sets: 2,
                durationSeconds: 20,
                restSeconds: 15,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "False Grip Dead Hang",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 15,
                    notes: "Wrist over the ring"
                ),
                sets: 2,
                durationSeconds: 15,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: currentLevel?.name ?? "Ring Support Hold",
                    category: .skillProgression,
                    setType: .reps,
                    defaultSets: 5,
                    defaultReps: currentLevel?.targetReps ?? 3,
                    notes: currentLevel?.details
                    ?? "Hold support, rings turned out"
                ),
                sets: 5,
                reps: currentLevel?.targetReps ?? 3,
                restSeconds: 120,
                notes: "Log actual reps and difficulty."
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: "Ring Dip",
                    category: .calisthenics,
                    setType: .reps,
                    defaultSets: 3,
                    defaultReps: 8,
                    notes: "Full ROM, rings turned out at top"
                ),
                sets: 3,
                reps: 8,
                restSeconds: 90
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Ring Pull-Up",
                    category: .calisthenics,
                    setType: .reps,
                    defaultSets: 3,
                    defaultReps: 6,
                    notes: "3s descent each rep"
                ),
                sets: 3,
                reps: 6,
                restSeconds: 90
            ),
        ] + ringStretches()
    }
    
    private func ringStretches() -> [WorkoutStep] {
        [
            WorkoutStep(
                exercise: Exercise(
                    name: "Doorframe Pec Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 45,
                    notes: "Each side"
                ),
                sets: 2,
                durationSeconds: 45,
                restSeconds: 15
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Passive Bar Hang",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Let shoulders fully relax"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 15
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Bicep Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Arm extended, palm up, rotate out"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 15
            ),
        ]
    }

}

