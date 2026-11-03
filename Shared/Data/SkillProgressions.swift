//
//  SkillProgressions.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//

import Foundation

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
    
    /// Maps the six-level Press Handstand path shipped before the weight-transfer revision.
    /// Stored sessions use this numeric level, so the mapping is deliberately permanent.
    static let legacyPressHandstandLevelMap = [1: 4, 2: 5, 3: 6, 4: 7, 5: 8, 6: 9]

    static let legacyPressHandstandExerciseNames = [
        "Feet-Elevated Straddle Press Drill",
        "Feet-Elevated Straddle Press"
    ]

    static func isLegacyPressHandstand(_ levels: [SkillLevel]) -> Bool {
        levels.count == 6
            && levels.contains { $0.level == 1 && $0.name == "Feet-Elevated Straddle Press Drill" }
            && levels.contains { $0.level == 6 && $0.name == "Straddle Press Handstand" }
    }

    static var pressHandstand: SkillProgression {
        SkillProgression(
            skillName: "Press Handstand",
            levels: [
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E01",
                    level: 1,
                    name: "Standing Straddle Compression / Foot Lifts",
                    details: "Use a comfortable standing straddle with hands on the floor or blocks. Keep each leg straight and alternately make one foot light, then lift it a little; the win is feeling the hip flexors lift the leg without needing a deep straddle. Count one controlled lift on each side as one rep.",
                    targetReps: 5
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E02",
                    level: 2,
                    name: "Feet-Elevated Pike Weight Shift",
                    details: "With feet together on a box or bench, hips high, and straight arms, push tall through the shoulders and slowly rock the shoulders over and slightly past the wrists. Keep the feet supported: success is being able to feel them become progressively lighter and return under control.",
                    targetReps: 5
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E03",
                    level: 3,
                    name: "Feet-Elevated Pike Toe Float",
                    details: "Use the same elevated pike. Shift until the feet are light enough to let the toes float briefly, then return with control. A momentary float counts; build toward repeatable, longer floats while keeping the elbows straight and shoulders pushing tall.",
                    targetReps: 3
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E04",
                    level: 4,
                    name: "Feet-Elevated Straddle Toe Float",
                    details: "From the elevated position, shift weight over the hands first, then let the legs open to a straddle as the support unloads. Aim for brief, controlled floats rather than a full press; success is finding the same light-feet position without losing shoulder pressure.",
                    targetReps: 3
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E05",
                    level: 5,
                    name: "Feet-Elevated Straddle Press Drill",
                    details: "With feet elevated, use the weight shift and toe float to press the straddled legs clear of the support with straight arms. The goal is a controlled, repeatable float and return—not forcing height before the centre of mass is over the hands.",
                    targetReps: 3
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E06",
                    level: 6,
                    name: "Wall Straddle Press Negative",
                    details: "From a chest-to-wall handstand, lower slowly through a wide straddle. Keep pressing tall and control the hips as they travel back over the hands; success is a quiet, even descent rather than dropping into the floor.",
                    targetReps: 3,
                    consecutiveSessions: 4,
                    maxAverageDifficulty: 3.0
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E07",
                    level: 7,
                    name: "Floor Straddle Press Negative",
                    details: "Lower from a freestanding handstand toward the floor with maximum control. Keep straight arms and use the straddle to keep the hips travelling over the hands; success is reaching the floor without a sudden loss of balance.",
                    targetReps: 3,
                    consecutiveSessions: 5,
                    maxAverageDifficulty: 3.0
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E08",
                    level: 8,
                    name: "Partial Straddle Press",
                    details: "From the floor, press until both feet clearly leave it while keeping the arms straight and shoulders active. Success is a controlled take-off with the hips moving over the hands, even before reaching handstand.",
                    targetReps: 3,
                    consecutiveSessions: 6,
                    maxAverageDifficulty: 3.5
                ),
                pressHandstandLevel(
                    id: "EF8B1264-584B-4A3E-A648-D43DB9278E09",
                    level: 9,
                    name: "Straddle Press Handstand",
                    details: "Complete a clean press from the floor to handstand with straight arms and control. The finish should feel like the same deliberate weight transfer continued upward, not a jump or kick.",
                    targetReps: 1,
                    consecutiveSessions: 6,
                    maxAverageDifficulty: 3.5
                )
            ],
            currentLevel: 1
        )
    }

    private static func pressHandstandLevel(
        id: String,
        level: Int,
        name: String,
        details: String,
        targetReps: Int,
        consecutiveSessions: Int = 3,
        maxAverageDifficulty: Double = 2.5
    ) -> SkillLevel {
        SkillLevel(
            id: UUID(uuidString: id) ?? UUID(),
            level: level,
            name: name,
            details: details,
            targetReps: targetReps,
            advanceCriteria: AdvanceCriteria(
                consecutiveSessions: consecutiveSessions,
                maxAverageDifficulty: maxAverageDifficulty,
                minReps: targetReps
            )
        )
    }
    
    static var compression: SkillProgression {
        SkillProgression(
            skillName: "Compression",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Tuck L-Sit",
                    details: "Press tall with both feet clear and knees tucked.",
                    targetDurationSeconds: 12,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 12
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Single-Leg L-Sit",
                    details: "Hold one leg straight; alternate sides without losing hip lift.",
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 10
                    )
                ),
                SkillLevel(
                    level: 3,
                    name: "L-Sit",
                    details: "Legs straight, hips lifted, shoulders depressed.",
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 10
                    )
                ),
                SkillLevel(
                    level: 4,
                    name: "High L-Sit",
                    details: "Lift straight legs above horizontal without leaning back.",
                    targetDurationSeconds: 8,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 4,
                        maxAverageDifficulty: 3.0,
                        minDurationSeconds: 8
                    )
                ),
                SkillLevel(
                    level: 5,
                    name: "V-Sit Prep",
                    details: "Raise straight legs toward the torso with hips held high.",
                    targetDurationSeconds: 6,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.5,
                        minDurationSeconds: 6
                    )
                ),
                SkillLevel(
                    level: 6,
                    name: "V-Sit",
                    details: "Hold straight legs high with hips lifted and shoulders depressed.",
                    targetDurationSeconds: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 6,
                        maxAverageDifficulty: 3.5,
                        minDurationSeconds: 5
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
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 10
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
                    name: "Half-Lay Front Lever",
                    details: "Extend the hips and knees partway while keeping a level body line.",
                    targetDurationSeconds: 6,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 5,
                        maxAverageDifficulty: 3.5,
                        minDurationSeconds: 6
                    )
                ),
                SkillLevel(
                    level: 6,
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
                    name: "Wall Balance & Release",
                    details: "Chest to wall; use controlled heel pulls for brief free balance.",
                    targetDurationSeconds: 10,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 3,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 10
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
                    name: "10s Freestanding Handstand",
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
                    name: "30s Freestanding Handstand",
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
                    name: "Handstand Walking",
                    details: "Take controlled steps while keeping shoulders tall and balance recoverable.",
                    targetReps: 5,
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 6,
                        maxAverageDifficulty: 3.0,
                        minReps: 5
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
