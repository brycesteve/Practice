//
//  SkillProgressions.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//

public enum SkillProgressions {
    public static var defaultSkillProgressions: [SkillProgression] {
        [SkillProgressions.planche, SkillProgressions.handstand, SkillProgressions.rings]
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
                    details: "Arms locked, rings turned out. Build to 3 × 30s.",
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
                    details:
                        "Full ROM, rings turned out at top. Build to 3 × 10.",
                    targetReps: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minReps: 10
                    )
                ),
                SkillLevel(
                    level: 3,
                    name: "False Grip Pull-Up",
                    details: "Wrist over the ring. Build to 3 × 5.",
                    targetReps: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minReps: 5
                    )
                ),
                SkillLevel(
                    level: 4,
                    name: "Muscle-Up Negative",
                    details:
                        "Jump to support, 5s descent through transition. Build to 5 × 3.",
                    targetReps: 3,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minReps: 3
                    )
                ),
                SkillLevel(
                    level: 5,
                    name: "Assisted Muscle-Up",
                    details:
                        "Band or jump assisted. Focus on transition. Build to 5 × 3.",
                    targetReps: 3,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.0,
                        minReps: 3
                    )
                ),
                SkillLevel(
                    level: 6,
                    name: "Ring Muscle-Up",
                    details: "Strict ring muscle-up from dead hang. The goal.",
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
