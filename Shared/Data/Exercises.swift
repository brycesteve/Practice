//
//  Exercises.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//

public enum Exercises {
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
