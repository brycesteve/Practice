//
//  Exercises.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//

public enum Exercises {
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
