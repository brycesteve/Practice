//
//  Exercises.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//

public enum Exercises {
    // Shared timed movements for the evening stretch and Thursday mobility sequences.
    private static func stretch(_ name: String, notes: String? = nil) -> Exercise {
        Exercise(name: name, category: .stretch, setType: .timed, defaultSets: 1,
                 defaultDuration: 30, notes: notes)
    }

    public static let hipOpeners = stretch("Hip Openers", notes: "Move gently between hip positions.")
    public static let gluteStretchLeft = stretch("90/90 Glute Stretch — Left Leg")
    public static let backLegLiftsRight = stretch("90/90 Back Leg Lifts — Right Leg", notes: "Lift and lower the back leg with control.")
    public static let ninetySeatedTwist = stretch("90/90 Seated Twist", notes: "Turn gently through the upper back.")
    public static let ninetyGoodMorningsLeft = stretch("90/90 Good Mornings — Left Leg", notes: "Hinge forward over the front leg with control.")
    public static let gluteStretchRight = stretch("90/90 Glute Stretch — Right Leg")
    public static let backLegLiftsLeft = stretch("90/90 Back Leg Lifts — Left Leg", notes: "Lift and lower the back leg with control.")
    public static let ninetyGoodMorningsRight = stretch("90/90 Good Mornings — Right Leg", notes: "Hinge forward over the front leg with control.")
    public static let catCow = stretch("Cat/Cow", notes: "Move slowly between comfortable spinal positions.")
    public static let forearmStretch = stretch("Forearm Stretch")
    public static let puppyDog = stretch("Puppy Dog Stretch")
    public static let shoulderRolls = stretch("Shoulder Rolls", notes: "Roll smoothly in both directions.")
    public static let downwardDog = stretch("Downward Dog Stretch", notes: "Let the heels lower gently to stretch the calves; they do not need to reach the floor.")
    public static let kneelingQuadLeft = stretch("Kneeling Quad Stretch — Left Leg Forward")
    public static let lizardLeft = stretch("Lizard Stretch — Left Leg Forward")
    public static let pigeonLeft = stretch("Pigeon Stretch — Left Leg Forward")
    public static let kneelingQuadRight = stretch("Kneeling Quad Stretch — Right Leg Forward")
    public static let lizardRight = stretch("Lizard Stretch — Right Leg Forward")
    public static let pigeonRight = stretch("Pigeon Stretch — Right Leg Forward")
    public static let frogStretch = stretch("Frog Stretch")
    public static let pancakeStretch = stretch("Seated Pancake Stretch")
    public static let pancakeSideLeft = stretch("Pancake Side Stretch — Left Foot")
    public static let pancakeSideRight = stretch("Pancake Side Stretch — Right Foot")
    public static let standingPike = stretch("Standing Pike Stretch")
    public static let deepSquatHold = stretch("Deep Squat Hold", notes: "Use a comfortable depth and support as needed.")
    public static let seatedBicepStretch = stretch("Seated Bicep Stretch")
    public static let lyingTwistLeft = stretch("Lying Twist — Left Leg Across")
    public static let lyingTwistRight = stretch("Lying Twist — Right Leg Across")
    public static let happyBaby = stretch("Happy Baby Stretch")
    public static let kneelingTSpineRotation = stretch("Kneeling T-Spine Rotation", notes: "Alternate sides within the interval.")
    public static let hipRocking = stretch("Hip Rocking — Feet Turned Out", notes: "Rock slowly through a comfortable range.")
    public static let downDogCalfPedal = stretch("Down Dog Calf Pedal", notes: "Alternate gently lowering each heel to stretch the calves.")
    public static let spinalWaves = stretch("Spinal Waves", notes: "Move smoothly without forcing the range.")
    public static let adductorRocksLeft = stretch("Half Kneeling Adductor Rocks — Left Foot Out")
    public static let frogThreadLeft = stretch("Half Frog Thread the Needle — Left Leg Straight", notes: "Move the right arm.")
    public static let adductorRocksRight = stretch("Half Kneeling Adductor Rocks — Right Foot Out")
    public static let frogThreadRight = stretch("Half Frog Thread the Needle — Right Leg Straight", notes: "Move the left arm.")
    public static let standingPancakeWalks = stretch("Standing Pancake Walks", notes: "Move side to side.")
    public static let pancakeShoulder = stretch("Pancake Shoulder Stretch")
    public static let toeStand = stretch("Toe Stand", notes: "Lift the heels with control; use support if needed.")
    public static let camelBridges = stretch("Camel Bridges", notes: "Alternate sides within the interval.")
    public static let activeCrabBicep = stretch("Active Crab Bicep Stretch")
    public static let proneAngels = stretch("Prone Angels", notes: "Move the arms with control.")
    public static let proneScorpions = stretch("Prone Scorpions", notes: "Alternate sides within the interval.")
    public static let birdDogLeft = stretch("Bird Dog — Left Hand & Right Leg", notes: "Lift and lower with control.")
    public static let hipFlexorRocksRight = stretch("Kneeling Hip Flexor Rocks — Right Leg Forward")
    public static let birdDogRight = stretch("Bird Dog — Right Hand & Left Leg", notes: "Lift and lower with control.")
    public static let hipFlexorRocksLeft = stretch("Kneeling Hip Flexor Rocks — Left Leg Forward")
    public static let hipCARsLeft = stretch("Kneeling Hip CARs — Left Leg", notes: "Slow controlled hip circles; keep the trunk steady.")
    public static let hipCARsRight = stretch("Kneeling Hip CARs — Right Leg", notes: "Slow controlled hip circles; keep the trunk steady.")
    public static let activeStandingPike = stretch("Standing Pike Stretch — Hands Off Floor")
    public static let lyingHipCirclesRight = stretch("Lying Hip Circles — Right Leg")
    public static let lyingLegExtensionsRight = stretch("Lying Leg Extensions — Right Leg")
    public static let lyingHipCirclesLeft = stretch("Lying Hip Circles — Left Leg")
    public static let lyingLegExtensionsLeft = stretch("Lying Leg Extensions — Left Leg")
    public static let bridgeHold = stretch("Bridge Hold", notes: "Use your comfortable bridge variation; do not force the backbend.")


    public static let armCircles = Exercise(
        name: "Arm Circles", category: .warmup, defaultSets: 1, defaultReps: 20,
        notes: "10 forward, 10 backward."
    )
    public static let shoulderRotations = Exercise(
        name: "Shoulder Rotations", category: .warmup, defaultSets: 1, defaultReps: 20,
        notes: "10 each direction. Move comfortably."
    )
    public static let bodyweightSquat = Exercise(
        name: "Bodyweight Squat", category: .warmup, defaultSets: 1, defaultReps: 10,
        notes: "10 comfortable reps."
    )
    // Separate warm-up variants keep preparation distinct in completed-workout history.
    public static let easyRingPushUp = Exercise(
        name: "Easy Ring Push-Up", category: .warmup, defaultSets: 1, defaultReps: 5,
        notes: "Use an easier angle than your working sets. Keep all 5 reps easy."
    )
    public static let easyRingRow = Exercise(
        name: "Easy Ring Row", category: .warmup, defaultSets: 1, defaultReps: 5,
        notes: "Use an easier angle than your working sets. Keep all 5 reps easy."
    )
    public static let lightClean = Exercise(
        name: "Light Kettlebell Clean", category: .warmup, defaultSets: 2, defaultReps: 3,
        notes: "3 per side: first set left, second set right. Choose a comfortably light kettlebell for preparation."
    )
    public static let lightPress = Exercise(
        name: "Light Kettlebell Press", category: .warmup, defaultSets: 2, defaultReps: 3,
        notes: "3 per side: first set left, second set right. Choose a comfortably light kettlebell for pressing preparation; do not infer it from swing or get-up weight."
    )

    public static let ringPushUp = Exercise(
        name: "Ring Push-Up", category: .calisthenics, defaultReps: 6,
        notes: "Adjust ring height and body position. Controlled reps; leave 2–3 reps in reserve."
    )
    public static let ringRow = Exercise(
        name: "Ring Row", category: .calisthenics, defaultReps: 6,
        notes: "Adjust ring height and body position. Keep the body controlled; leave 2–3 reps in reserve."
    )
    public static let strengthGobletSquat = Exercise(
        name: "Goblet Squat", category: .kettlebell, defaultSets: 2, defaultReps: 5,
        notes: "Use a comfortable range. Do not force knee depth or load; leave 2–3 reps in reserve."
    )
    public static let hangingKneeRaise = Exercise(
        name: "Hanging Bent-Knee Raise", category: .calisthenics, defaultSets: 2, defaultReps: 8,
        notes: "Controlled repetitions without swinging; leave 2–3 reps in reserve."
    )
    public static let cleanPressLeft = Exercise(
        name: "Kettlebell Clean & Press — Left", category: .kettlebell, defaultReps: 5,
        notes: "Choose a technically comfortable pressing load independently of get-up weight. Leave 2–3 reps in reserve."
    )
    public static let cleanPressRight = Exercise(
        name: "Kettlebell Clean & Press — Right", category: .kettlebell, defaultReps: 5,
        notes: "Clean and press each repetition with control; leave 2–3 reps in reserve."
    )
    public static let strengthPullUp = Exercise(
        name: "Pull-Up / Assisted Pull-Up", category: .calisthenics, setType: .repRange, defaultReps: 3,
        notes: "Use assistance as needed for 3–5 clean reps. Leave 2–3 reps in reserve; avoid failure."
    )
    public static let ankleRocks = Exercise(
        name: "Supported Ankle Rocks", category: .stretch, setType: .timed, defaultSets: 2, defaultDuration: 30,
        notes: "One 30s set per side. Hold a wall for support, keep the heel down and gently move the knee forward and back. Stay within a comfortable ankle and knee range; do not force it."
    )
    public static let thoracicRotation = Exercise(
        name: "Seated Thoracic Rotation", category: .stretch, setType: .timed, defaultSets: 2, defaultDuration: 30,
        notes: "One 30s set per side. Sit tall on a stable chair, arms across the chest. Slowly turn the upper back and return to centre, keeping hips still. No forced twisting."
    )
    public static let jointStretches = Exercise(
        name: "Joint Stretches", category: .stretch, setType: .timed, defaultSets: 1,
        notes: "Follow your usual morning joint mobility routine at your own pace. Finish when ready."
    )

    public static let ninetyNinety = Exercise(
        name: "90/90 Stretch",
        category: .stretch,
        setType: .timed,
        defaultSets: 4,
        defaultDuration: 30,
        notes: "Alternate sides"
    )
    
    public static let qlStraddle = Exercise(
        name: "QL Straddle",
        category: .stretch,
        setType: .timed,
        defaultSets: 4,
        defaultDuration: 30,
        notes: "Alternate Sides"
    )
    
    public static let barHang = Exercise(
        name: "Bar hang",
        category: .stretch,
        setType: .timed,
        defaultSets: 2,
        defaultDuration: 60,
        notes: "Dead hang"
    )
    
    public static let hamstringStretch = Exercise(
        name: "Hamstring Stretch",
        category: .stretch,
        setType: .timed,
        defaultSets: 4,
        defaultDuration: 30,
        notes: "Alternate Sides"
    )
    
    public static let hipFlexorStretch = Exercise(
        name: "Hip Flexor Stretch",
        category: .stretch,
        setType: .timed,
        defaultSets: 4,
        notes: "Alternate Sides"
    )
    
    public static let gobletSquat = Exercise(
        name: "Prying Goblet Squat",
        category: .warmup,
        setType: .reps,
        defaultSets: 3,
        defaultReps: 5,
        notes: "Hold bottom 3–5s each rep"
    )
    
    public static let halo = Exercise(
        name: "Halo",
        category: .warmup,
        setType: .reps,
        defaultSets: 3,
        defaultReps: 5,
        notes: "Both directions"
    )
    
    public static let hipRaise = Exercise(
        name: "Hip Raise",
        category: .warmup,
        setType: .reps,
        defaultSets: 3,
        defaultReps: 5,
        notes: ""
    )
    
    public static let kbSwing = Exercise(
        name: "Kettlebell Swing",
        category: .kettlebell,
        setType: .reps,
        defaultSets: 10,
        defaultReps: 10,
        notes:
            "Alternate hands each set. Explosive hip hinge. Log weight per set."
    )
    
    public static let tgu = Exercise(
        name: "Turkish Get-Up",
        category: .kettlebell,
        setType: .reps,
        defaultSets: 10,
        defaultReps: 1,
        notes:
            "5L / 5R alternating. Slow and deliberate. Log weight per rep."
    )
    
    public static let pushUp = Exercise(
        name: "Push-Up Variation",
        category: .calisthenics,
        setType: .reps,
        defaultSets: 3,
        defaultReps: 10,
        notes:
            "Standard, archer, or deficit."
    )
    
    public static let pullUp = Exercise(
        name: "Pull-Up",
        category: .calisthenics,
        setType: .reps,
        defaultSets: 3,
        defaultReps: 5,
        notes: "Dead hang each rep."
    )
    
    public static let wristStretches = Exercise(
        name: "Wrist Circles & Extensions",
        category: .warmup,
        setType: .timed,
        defaultSets: 2,
        defaultDuration: 30,
        notes: "30s each direction"
    )
    
    public static let scapPushUp = Exercise(
        name: "Scapula Push-Up",
        category: .warmup,
        setType: .reps,
        defaultSets: 2,
        defaultReps: 10,
        notes: "Protract and retract fully"
    )
    
    public static let scapPullUp = Exercise(
        name: "Scapula Pull-Up",
        category: .warmup,
        setType: .reps,
        defaultSets: 2,
        defaultReps: 5,
        notes: "Protract and retract fully"
    )
    
    public static let psuedoPlanchePush = Exercise(
        name: "Pseudo Planche Push-Up",
        category: .calisthenics,
        setType: .reps,
        defaultSets: 3,
        defaultReps: 8,
        notes: "Lean forward, protract scapulae"
    )
    public static let plancheLeanHold = Exercise(
        name: "Planche Lean Hold",
        category: .calisthenics,
        setType: .timed,
        defaultSets: 3,
        defaultDuration: 20,
        notes: "Straight body, lean past hands"
    )
}
