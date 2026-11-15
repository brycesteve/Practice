

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

    func routine(from progressions: [SkillProgression], on date: Date = .now,
                 calendar: Calendar = .current) -> [WorkoutStep] {
        let stretches = calendar.component(.weekday, from: date) == 5 ? [] : Self.commonStretches()
        return practiceSteps(from: progressions) + stretches + WorkoutData.barHangSteps
    }

    /// Skill identity checks must not assemble the full stretch routine for every record.
    func practiceSteps(from progressions: [SkillProgression]) -> [WorkoutStep] {
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
        
        return routine
    }

    static func commonStretches() -> [WorkoutStep] {
        WorkoutData.eveningStretchSteps
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
            
        ]
    }

    private func handstandRoutine(currentLevel: SkillLevel?)
    -> [WorkoutStep]
    {
        let warmupGroup = UUID()
        let isTimedProgression = currentLevel?.targetDurationSeconds != nil || currentLevel == nil
        let progressionDuration = currentLevel?.targetDurationSeconds ?? 30
        let progressionReps = currentLevel?.targetReps ?? 5
       
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
                    setType: isTimedProgression ? .timed : .reps,
                    defaultSets: 5,
                    defaultReps: isTimedProgression ? nil : progressionReps,
                    defaultDuration: isTimedProgression ? progressionDuration : nil,
                    notes: currentLevel?.details
                    ?? "Hold against wall, chest to wall"
                ),
                sets: 5,
                reps: isTimedProgression ? nil : progressionReps,
                durationSeconds: isTimedProgression ? progressionDuration : nil,
                restSeconds: 90,
                notes: isTimedProgression
                    ? "Log your best clean hold and difficulty."
                    : "Log controlled steps and difficulty."
            )
        ]
    }

    private func ringsRoutine(currentLevel: SkillLevel?)
    -> [WorkoutStep]
    {
        let warmupGroup = UUID()
        let isTimedProgression = currentLevel?.targetDurationSeconds != nil || currentLevel == nil
        let progressionDuration = currentLevel?.targetDurationSeconds ?? 30
        let progressionReps = currentLevel?.targetReps ?? 3
        
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
                    name: currentLevel?.name ?? "Ring Support Hold",
                    category: .skillProgression,
                    setType: isTimedProgression ? .timed : .reps,
                    defaultSets: 5,
                    defaultReps: isTimedProgression ? nil : progressionReps,
                    defaultDuration: isTimedProgression ? progressionDuration : nil,
                    notes: currentLevel?.details
                    ?? "Hold support, rings turned out"
                ),
                sets: 5,
                reps: isTimedProgression ? nil : progressionReps,
                durationSeconds: isTimedProgression ? progressionDuration : nil,
                restSeconds: 120,
                notes: isTimedProgression
                    ? "Log actual hold time and difficulty."
                    : "Log actual reps and difficulty."
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
                    defaultDuration: currentLevel?.targetDurationSeconds ?? 10,
                    notes: currentLevel?.details
                    ?? "Knees tucked. Hips in line with elbows"
                ),
                sets: 5,
                durationSeconds: currentLevel?.targetDurationSeconds ?? 10,
                restSeconds: 120,
                notes: "Log actual hold time and difficulty."
            ),
            
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
                    name: currentLevel?.name ?? "Compression Hold",
                    category: .skillProgression,
                    setType: .timed,
                    defaultSets: 5,
                    defaultDuration: currentLevel?.targetDurationSeconds ?? 15,
                    notes: currentLevel?.details
                    ?? "Hold active pike compression."
                ),
                sets: 5,
                durationSeconds: currentLevel?.targetDurationSeconds ?? 15,
                restSeconds: 120,
                notes: "Log actual hold time and difficulty."
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
                    name: "Pike Compression Pulses",
                    category: .warmup,
                    setType: .reps,
                    defaultSets: 2,
                    defaultReps: 10,
                    notes: "Pike sit and lift feet"
                ),
                sets: 2,
                reps: 10,
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
                    name: currentLevel?.name ?? "Feet-Elevated Straddle Press Drill",
                    category: .skillProgression,
                    setType: .reps,
                    defaultSets: 5,
                    defaultReps: currentLevel?.targetReps ?? 5,
                    notes: currentLevel?.details
                    ?? "Feet on a sofa or chair; lean forward and lift the hips to unload the feet."
                ),
                sets: 5,
                reps: currentLevel?.targetReps ?? 5,
                restSeconds: 90,
                notes: "Log actual reps and difficulty."
            ),
            
        ]
    }

}
