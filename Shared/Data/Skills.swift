

import Foundation
import SwiftUI



public enum Skill: String, RawRepresentable, CaseIterable {
    case planche = "Planche"
    case handstand = "Handstand"
    case rings = "Ring Skills"
    case pressHandstand = "Press Handstand"
    case compression = "Compression"
    case frontLever = "Front Lever"
    
    static var activeSkills: [Skill] {
        [
            .planche,
            .rings,
            .handstand,
            .frontLever,
            .compression,
            .pressHandstand
        ]
    }
    
    var icon: String {
        switch self {
        case .planche:     return "figure.strengthtraining.traditional"
        case .handstand:   return "figure.cooldown"
        case .rings: return "link"
        case .compression: return "figure.flexibility"
        case .frontLever: return "figure.rower"
        case .pressHandstand: return "figure.mind.and.body"
        }
    }
    
    var color: Color {
        switch self {
        case .planche:     return .purple
        case .handstand:   return .blue
        case .rings: return .orange
        case .compression: return .red
        case .frontLever: return .indigo
        case .pressHandstand: return .green
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
        case .compression: return compressionRoutine(currentLevel: currentLevel)
        case .frontLever: return frontLeverRoutine(currentLevel: currentLevel)
        case .pressHandstand: return pressHandstandRoutine(currentLevel: currentLevel)
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
                restSeconds: 10,
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
            )
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
                    name: "False Grip Pulses",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 20,
                    notes: "Strengthen wrists"
                ),
                sets: 2,
                durationSeconds: 20,
                restSeconds: 15,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercises.scapPullUp,
                sets: 2,
                reps: 5,
                restSeconds: 20,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercises.scapPushUp,
                sets: 2,
                reps: 5,
                restSeconds: 20,
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
                    notes: "Full thoracic mobility"
                ),
                sets: 2,
                durationSeconds: 45,
                restSeconds: 15
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "German Hang",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Full shoulder retraction"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 60
            ),
        ]
    }

    
    private func frontLeverRoutine(currentLevel: SkillLevel?)
    -> [WorkoutStep]
    {
        let warmupGroup = UUID()
        return [
            WorkoutStep(
                exercise: Exercise(
                    name: "Dead Hang",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 15,
                    notes: "Total dead hang"
                ),
                sets: 2,
                durationSeconds: 15,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercises.scapPullUp,
                sets: 2,
                reps: 5,
                restSeconds: 20,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Hollow hold",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 15,
                    notes: "Hold anterior tension"
                ),
                sets: 2,
                durationSeconds: 15,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: currentLevel?.name ?? "Tuck Front Lever",
                    category: .skillProgression,
                    setType: .timed,
                    defaultSets: 5,
                    defaultReps: currentLevel?.targetDurationSeconds ?? 15,
                    notes: currentLevel?.details
                    ?? "Kness Tucked. Hips in line with elbows"
                ),
                sets: 5,
                durationSeconds: currentLevel?.targetDurationSeconds ?? 15,
                restSeconds: 120,
                notes: "Log actual reps and difficulty."
            ),
            
        ] + frontLeverStretches()
    }
    
    private func frontLeverStretches() -> [WorkoutStep] {
        [
            
        ]
    }
    
    private func compressionRoutine(currentLevel: SkillLevel?)
    -> [WorkoutStep]
    {
        let warmupGroup = UUID()
        return [
            WorkoutStep(
                exercise: Exercise(
                    name: "Pike Compression Pulses",
                    category: .warmup,
                    setType: .reps,
                    defaultSets: 2,
                    defaultReps: 10,
                    notes: "Pike sit and lift feet"
                ),
                sets: 2,
                reps: 15,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: "Hollow hold",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 15,
                    notes: "Hold anterior tension"
                ),
                sets: 2,
                durationSeconds: 15,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
            
            WorkoutStep(
                exercise: Exercise(
                    name: currentLevel?.name ?? "Tuck Front Lever",
                    category: .skillProgression,
                    setType: .timed,
                    defaultSets: 5,
                    defaultReps: currentLevel?.targetDurationSeconds ?? 15,
                    notes: currentLevel?.details
                    ?? "Kness Tucked. Hips in line with elbows"
                ),
                sets: 5,
                durationSeconds: currentLevel?.targetDurationSeconds ?? 15,
                restSeconds: 120,
                notes: "Log actual reps and difficulty."
            ),
            
        ] + compressionStretches()
    }
    
    private func compressionStretches() -> [WorkoutStep] {
        [
            WorkoutStep(
                exercise: Exercise(
                    name: "Pancake Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Straddle forward fold"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 30
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Calf Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 4,
                    defaultDuration: 30,
                    notes: "Toe on step and stretch down. Alternate sides"
                ),
                sets: 4,
                durationSeconds: 30,
                restSeconds: 15
            ),
        ]
    }
    
    private func pressHandstandRoutine(currentLevel: SkillLevel?)
    -> [WorkoutStep]
    {
        let warmupGroup = UUID()
        return [
            WorkoutStep(
                exercise: Exercise(
                    name: "Pike Compression pulses",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 20,
                    notes: "Pike sit and lift feet"
                ),
                sets: 2,
                durationSeconds: 20,
                restSeconds: 15,
                circuitGroupID: warmupGroup
            ),
            
            WorkoutStep(
                exercise: Exercises.wristStretches,
                sets: 2,
                durationSeconds: 30,
                restSeconds: 10,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Wall shoulder shrug",
                    category: .warmup,
                    setType: .reps,
                    defaultSets: 2,
                    defaultReps: 10,
                    notes: "Full movement of shoulders"
                ),
                sets: 2,
                reps: 10,
                restSeconds: 15,
                circuitGroupID: warmupGroup
            ),
            WorkoutStep(
                exercise: Exercise(
                    name: "Crow pose hold",
                    category: .warmup,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 20,
                    notes: "Crow pose"
                ),
                sets: 2,
                durationSeconds: 20,
                restSeconds: 30,
                circuitGroupID: warmupGroup
            ),
        
            
            WorkoutStep(
                exercise: Exercise(
                    name: currentLevel?.name ?? "Pike compression lift",
                    category: .skillProgression,
                    setType: .reps,
                    defaultSets: 5,
                    defaultReps: currentLevel?.targetReps ?? 10,
                    notes: currentLevel?.details
                    ?? "Lift feet briefly from seated pike."
                ),
                sets: 5,
                reps: currentLevel?.targetReps ?? 10,
                restSeconds: 60,
                notes: "Log actual reps and difficulty."
            ),
            
        ] + pressHandstandStretches()
    }
    
    private func pressHandstandStretches() -> [WorkoutStep] {
        [
            WorkoutStep(
                exercise: Exercise(
                    name: "Pancake Stretch",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Straddle forward fold"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 30
            ),
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
                    name: "Bridge Hold",
                    category: .stretch,
                    setType: .timed,
                    defaultSets: 2,
                    defaultDuration: 30,
                    notes: "Full thoracic extension"
                ),
                sets: 2,
                durationSeconds: 30,
                restSeconds: 30
            ),
        ]
    }


}

