//
//  SkillProgressions.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//

public enum SkillProgressions {
    public static var defaultSkillProgressions: [SkillProgression] {
        [
            SkillProgressions.planche,
            SkillProgressions.rings,
            SkillProgressions.handstand,
            SkillProgressions.frontLever,
            SkillProgressions.compression,
            SkillProgressions.pressHandstand
        ]
    }
    
    static var pressHandstand: SkillProgression {
        SkillProgression(
            skillName: "Press Handstand",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Pike Compression Lift",
                    details: "Lift feet briefly from seated pike.",
                    targetReps: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minReps: 10
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Crow Stand",
                    details: "Balance knees on elbows.",
                    targetDurationSeconds: 20,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 20
                    )
                ),
                SkillLevel(
                    level: 3,
                    name: "Tuck Press Negative",
                    details: "Slow lowering from handstand into tuck.",
                    targetReps: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minReps: 5
                    )
                ),
                SkillLevel(
                    level: 4,
                    name: "Box Press Handstand",
                    details: "Use elevated feet to reduce load.",
                    targetReps: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.0,
                        minReps: 5
                    )
                ),
                SkillLevel(
                    level: 5,
                    name: "Straddle Press Handstand",
                    details: "Controlled press into handstand.",
                    targetReps: 1,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 6,
                        maxAverageDifficulty: 3.5,
                        minReps: 1
                    )
                ),
            ],
            currentLevel: 1
        )
    }
    
    static var compression: SkillProgression {
        SkillProgression(
            skillName: "Compression",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Tuck Sit",
                    details: "Feet lifted slightly with knees tucked.",
                    targetDurationSeconds: 20,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 20
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Single Leg Extension",
                    details: "Alternate one leg extended while maintaining lift.",
                    targetDurationSeconds: 20,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 20
                    )
                ),
                SkillLevel(
                    level: 3,
                    name: "L-Sit",
                    details: "Legs straight, hips lifted, shoulders depressed.",
                    targetDurationSeconds: 15,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 15
                    )
                ),
                SkillLevel(
                    level: 4,
                    name: "Extended L-Sit",
                    details: "Longer hold with active compression.",
                    targetDurationSeconds: 30,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 30
                    )
                ),
                SkillLevel(
                    level: 5,
                    name: "V-Sit Prep",
                    details: "Elevate legs above horizontal briefly.",
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.5,
                        minDurationSeconds: 10
                    )
                ),
            ],
            currentLevel: 1
        )
    }
    
    static var frontLever: SkillProgression {
        SkillProgression(
            skillName: "Front Lever",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Tuck Front Lever",
                    details: "Knees tucked, hips level with shoulders.",
                    targetDurationSeconds: 15,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 15
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Advanced Tuck Front Lever",
                    details: "Open hips slightly while maintaining flat back.",
                    targetDurationSeconds: 12,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 12
                    )
                ),
                SkillLevel(
                    level: 3,
                    name: "One Leg Front Lever",
                    details: "Alternate extended leg while maintaining body line.",
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 10
                    )
                ),
                SkillLevel(
                    level: 4,
                    name: "Straddle Front Lever",
                    details: "Wide straddle with flat hips and straight arms.",
                    targetDurationSeconds: 8,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 8
                    )
                ),
                SkillLevel(
                    level: 5,
                    name: "Full Front Lever",
                    details: "Body parallel with legs together.",
                    targetDurationSeconds: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.5,
                        minDurationSeconds: 5
                    )
                ),
            ],
            currentLevel: 1
        )
    }
    
    static var planche: SkillProgression {
        SkillProgression(
            skillName: "Planche",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Planche Lean",
                    details:
                        "Lean forward, straight arms, shoulders past hands. Hold.",
                    targetDurationSeconds: 30,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 30
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Tuck Planche",
                    details:
                        "Knees to chest, hips at hand height. Hold off the floor.",
                    targetDurationSeconds: 15,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 15
                    )
                ),
                SkillLevel(
                    level: 3,
                    name: "Advanced Tuck Planche",
                    details: "Back flat parallel to floor, knees still tucked.",
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 10
                    )
                ),
                SkillLevel(
                    level: 4,
                    name: "Straddle Planche",
                    details:
                        "Legs extended and straddled wide, body horizontal.",
                    targetDurationSeconds: 8,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 8
                    )
                ),
                SkillLevel(
                    level: 5,
                    name: "Half-Lay Planche",
                    details:
                        "Legs straddled but closing, approaching full planche.",
                    targetDurationSeconds: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.5,
                        minDurationSeconds: 5
                    )
                ),
                SkillLevel(
                    level: 6,
                    name: "Full Planche",
                    details: "Legs together, fully horizontal. The goal.",
                    targetDurationSeconds: 3,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 6,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 3
                    )
                ),
            ],
            currentLevel: 1
        )
    }
    
    static var handstand: SkillProgression {
        SkillProgression(
            skillName: "Handstand",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Wall Handstand (Chest to Wall)",
                    details:
                        "Face wall, work on vertical alignment and wrist position.",
                    targetDurationSeconds: 60,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 60
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Wall Handstand (Back to Wall)",
                    details:
                        "Back to wall. Reduce reliance on wall, engage lats and shoulders.",
                    targetDurationSeconds: 45,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 45
                    )
                ),
                SkillLevel(
                    level: 3,
                    name: "Kick-Up & Balance Attempts",
                    details: "Kick to freestanding. Log best hold per set.",
                    targetDurationSeconds: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 5
                    )
                ),
                SkillLevel(
                    level: 4,
                    name: "Freestanding Handstand (5–10s)",
                    details: "Consistent holds. Focus on finger balancing.",
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 10
                    )
                ),
                SkillLevel(
                    level: 5,
                    name: "Freestanding Handstand (30s)",
                    details: "Solid 30s hold with clean body line.",
                    targetDurationSeconds: 30,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 30
                    )
                ),
                SkillLevel(
                    level: 6,
                    name: "Handstand Walk & Press",
                    details: "Walking, pirouettes, and press from straddle.",
                    targetDurationSeconds: 60,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 6,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 60
                    )
                ),
            ],
            currentLevel: 1
        )
    }
    
    static var rings: SkillProgression {
        SkillProgression(
            skillName: "Ring Skills",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Ring Support Hold",
                    details: "Arms locked, rings turned out slightly. Build stability.",
                    targetDurationSeconds: 30,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 30
                    )
                ),
                
                SkillLevel(
                    level: 2,
                    name: "Ring Dip",
                    details: "Controlled full ROM dips with stable support.",
                    targetReps: 8,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minReps: 8
                    )
                ),
                
                SkillLevel(
                    level: 3,
                    name: "False Grip Hang",
                    details: "Develop wrist tolerance and false grip endurance.",
                    targetDurationSeconds: 30,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 30
                    )
                ),
                
                SkillLevel(
                    level: 4,
                    name: "False Grip Pull-Up",
                    details: "Pull chest high while maintaining false grip.",
                    targetReps: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minReps: 5
                    )
                ),
                
                SkillLevel(
                    level: 5,
                    name: "Low Ring Transition",
                    details: "Practice transition mechanics close to the floor.",
                    targetReps: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minReps: 5
                    )
                ),
                
                SkillLevel(
                    level: 6,
                    name: "Muscle-Up Negative",
                    details: "Controlled descent through transition.",
                    targetReps: 3,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minReps: 3
                    )
                ),
                
                SkillLevel(
                    level: 7,
                    name: "Assisted Ring Muscle-Up",
                    details: "Band or foot-assisted full movement.",
                    targetReps: 3,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.0,
                        minReps: 3
                    )
                ),
                
                SkillLevel(
                    level: 8,
                    name: "Strict Ring Muscle-Up",
                    details: "Controlled strict muscle-up from dead hang.",
                    targetReps: 1,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.5,
                        minReps: 1
                    )
                ),
            ],
            currentLevel: 1
        )
    }
    
}
