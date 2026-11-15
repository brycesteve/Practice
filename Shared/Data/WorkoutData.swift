//
//  WorkoutData.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//
import Foundation

public enum WorkoutData {
    
    public static let kbWeights: [Double] = [8, 16, 24, 28, 32, 40, 48]
    
    public static let strengthWeights: [Double] = [8, 16, 24, 32, 40, 48]

    /// The existing programme, advanced by logged sessions rather than weekdays.
    static let mainSequence: [SessionType] = [.morning, .strengthA, .morning, .mobility, .morning, .strengthB]

    static var restEveningPlan: SessionPlan {
        SessionPlan(sessionType: .evening, steps: eveningStretchSteps,
                    estimatedDurationMinutes: estimatedMinutes(for: eveningStretchSteps))
    }

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
        [WorkoutStep(exercise: Exercises.armCircles, sets: 1, reps: 20, restSeconds: 0,
                     notes: "Warm-up: approximately 3–4 minutes, at your own pace."),
         WorkoutStep(exercise: Exercises.scapPushUp, sets: 1, reps: 10, restSeconds: 0),
         WorkoutStep(exercise: Exercises.bodyweightSquat, sets: 1, reps: 10, restSeconds: 0),
         WorkoutStep(exercise: Exercises.easyRingPushUp, sets: 1, reps: 5, restSeconds: 0),
         WorkoutStep(exercise: Exercises.easyRingRow, sets: 1, reps: 5, restSeconds: 0),
         strengthStep(Exercises.ringPushUp, sets: 3, reps: 6),
         strengthStep(Exercises.ringRow, sets: 3, reps: 6),
         strengthStep(Exercises.strengthGobletSquat, sets: 2, reps: 5, loadKey: "gobletSquat"),
         strengthStep(Exercises.hangingKneeRaise, sets: 2, reps: 8)]
    }

    public static var strengthBSteps: [WorkoutStep] {
        let sides = UUID()
        return [
            WorkoutStep(exercise: Exercises.armCircles, sets: 1, reps: 20, restSeconds: 0,
                        notes: "Warm-up: approximately 4–5 minutes, at your own pace."),
            WorkoutStep(exercise: Exercises.shoulderRotations, sets: 1, reps: 20, restSeconds: 0),
            WorkoutStep(exercise: Exercises.halo, sets: 1, reps: 10, restSeconds: 0,
                        notes: "5 each direction. Use a comfortably light kettlebell."),
            WorkoutStep(exercise: Exercises.lightClean, sets: 2, reps: 3, restSeconds: 0),
            WorkoutStep(exercise: Exercises.lightPress, sets: 2, reps: 3, restSeconds: 0),
            WorkoutStep(exercise: Exercises.scapPullUp, sets: 1, reps: 5, restSeconds: 0),
            strengthStep(Exercises.cleanPressLeft, sets: 3, reps: 5, loadKey: "cleanPress", circuit: sides),
            strengthStep(Exercises.cleanPressRight, sets: 3, reps: 5, loadKey: "cleanPress", circuit: sides),
            strengthStep(Exercises.strengthPullUp, sets: 3, reps: 3, upperReps: 5),
            strengthStep(Exercises.ringPushUp, sets: 2, reps: 6),
            strengthStep(Exercises.hangingKneeRaise, sets: 2, reps: 8)
        ]
    }

    // Follow-along sequence order with separate evening and Thursday timings.
    // Dynamic movements are performed slowly for the interval, rather than held.
    private static func stretchStep(_ exercise: Exercise, notes: String? = nil) -> WorkoutStep {
        WorkoutStep(exercise: exercise, sets: 1, durationSeconds: 30, restSeconds: 10, notes: notes)
    }

    private static func mobilityStep(_ exercise: Exercise, sets: Int = 1) -> WorkoutStep {
        WorkoutStep(exercise: exercise, sets: sets, durationSeconds: 45, restSeconds: 10)
    }

    public static var eveningStretchSteps: [WorkoutStep] {
        [
            stretchStep(Exercises.hipOpeners),
            stretchStep(Exercises.gluteStretchLeft),
            stretchStep(Exercises.backLegLiftsRight),
            stretchStep(Exercises.ninetySeatedTwist, notes: "Left leg in front."),
            stretchStep(Exercises.ninetyGoodMorningsLeft),
            stretchStep(Exercises.gluteStretchRight),
            stretchStep(Exercises.backLegLiftsLeft),
            stretchStep(Exercises.ninetySeatedTwist, notes: "Right leg in front."),
            stretchStep(Exercises.ninetyGoodMorningsRight),
            stretchStep(Exercises.catCow),
            stretchStep(Exercises.forearmStretch),
            stretchStep(Exercises.puppyDog),
            stretchStep(Exercises.shoulderRolls),
            stretchStep(Exercises.downwardDog),
            stretchStep(Exercises.kneelingQuadLeft),
            stretchStep(Exercises.lizardLeft),
            stretchStep(Exercises.pigeonLeft),
            stretchStep(Exercises.kneelingQuadRight),
            stretchStep(Exercises.lizardRight),
            stretchStep(Exercises.pigeonRight),
            stretchStep(Exercises.frogStretch),
            stretchStep(Exercises.pancakeStretch),
            stretchStep(Exercises.pancakeSideLeft),
            stretchStep(Exercises.pancakeSideRight),
            stretchStep(Exercises.standingPike),
            stretchStep(Exercises.deepSquatHold),
            stretchStep(Exercises.seatedBicepStretch),
            stretchStep(Exercises.lyingTwistLeft),
            stretchStep(Exercises.lyingTwistRight),
            stretchStep(Exercises.happyBaby),
        ]
    }

    public static var barHangSteps: [WorkoutStep] {
        [WorkoutStep(exercise: Exercises.barHang, sets: 2, durationSeconds: 60, restSeconds: 60)]
    }

    public static var mobilitySteps: [WorkoutStep] {
        [
            mobilityStep(Exercises.catCow),
            mobilityStep(Exercises.kneelingTSpineRotation),
            mobilityStep(Exercises.hipRocking),
            mobilityStep(Exercises.downDogCalfPedal),
            mobilityStep(Exercises.spinalWaves),
            mobilityStep(Exercises.adductorRocksLeft),
            mobilityStep(Exercises.frogThreadLeft),
            mobilityStep(Exercises.adductorRocksRight),
            mobilityStep(Exercises.frogThreadRight),
            mobilityStep(Exercises.standingPancakeWalks),
            mobilityStep(Exercises.pancakeShoulder),
            mobilityStep(Exercises.toeStand),
            mobilityStep(Exercises.camelBridges),
            mobilityStep(Exercises.activeCrabBicep),
            mobilityStep(Exercises.proneAngels),
            mobilityStep(Exercises.proneScorpions),
            mobilityStep(Exercises.birdDogLeft),
            mobilityStep(Exercises.hipFlexorRocksRight),
            mobilityStep(Exercises.birdDogRight),
            mobilityStep(Exercises.hipFlexorRocksLeft),
            mobilityStep(Exercises.hipCARsLeft),
            mobilityStep(Exercises.hipCARsRight),
            mobilityStep(Exercises.deepSquatHold),
            mobilityStep(Exercises.activeStandingPike),
            mobilityStep(Exercises.lyingHipCirclesRight),
            mobilityStep(Exercises.lyingLegExtensionsRight),
            mobilityStep(Exercises.lyingTwistRight),
            mobilityStep(Exercises.lyingHipCirclesLeft),
            mobilityStep(Exercises.lyingLegExtensionsLeft),
            mobilityStep(Exercises.lyingTwistLeft),
            // Assistance only; no skill progression or additional evening bridge work.
            mobilityStep(Exercises.bridgeHold, sets: 2)
        ]
    }

    public static func plan(for type: SessionType, rotationDay: Int = 0,
                            progressions: [SkillProgression] = [], on date: Date = .now,
                            calendar: Calendar = .current) -> SessionPlan {
        let steps: [WorkoutStep]
        let minutes: Int
        switch type {
        case .morning: steps = morningSteps; minutes = 45
        case .strengthA: steps = strengthASteps; minutes = 29
        case .strengthB: steps = strengthBSteps; minutes = 35
        case .mobility: steps = mobilitySteps; minutes = estimatedMinutes(for: steps)
        case .jointStretches:
            steps = [WorkoutStep(exercise: Exercises.jointStretches, sets: 1, restSeconds: 0)]
            minutes = 0 // Open duration: no target or countdown.
        case .evening:
            steps = eveningSteps(rotationDay: rotationDay, progressions: progressions, on: date, calendar: calendar)
            minutes = estimatedMinutes(for: steps)
        }
        return SessionPlan(sessionType: type, steps: steps, estimatedDurationMinutes: minutes)
    }

    static func eveningPlan(for skill: Skill, progressions: [SkillProgression],
                            on date: Date = .now, calendar: Calendar = .current) -> SessionPlan {
        let steps = skill.routine(from: progressions, on: date, calendar: calendar)
        return SessionPlan(sessionType: .evening, steps: steps,
                           estimatedDurationMinutes: estimatedMinutes(for: steps))
    }

    private static func estimatedMinutes(for steps: [WorkoutStep]) -> Int {
        // Rep-based warm-ups use a rough 3 seconds per rep. No final rest is needed.
        let seconds = steps.reduce(0) { total, step in
            total + step.sets * ((step.durationSeconds ?? (step.reps ?? 0) * 3) + step.restSeconds)
        } - (steps.last?.restSeconds ?? 0)
        return max(1, (seconds + 59) / 60)
    }

    // MARK: - Evening Rotation
    
    public static func eveningSteps(
        rotationDay: Int,
        progressions: [SkillProgression],
        on date: Date = .now, calendar: Calendar = .current
    ) -> [WorkoutStep] {
        let skillIndex = EveningRotation.normalized(rotationDay)
        let skill = Skill.activeSkills[skillIndex]
        return skill.routine(from: progressions, on: date, calendar: calendar)
    }
    
    
    
}
