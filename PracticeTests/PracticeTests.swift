import Foundation
import Testing
@testable import Practice

@Suite("Progression engine")
struct ProgressionEngineTests {
    private let engine = ProgressionEngine()

    @Test("Maintains when the current level is missing")
    func missingCurrentLevel() {
        let progression = makeProgression(currentLevel: 99)
        let recommendation = engine.evaluate(progression: progression, history: [])

        guard case .maintain(let reason) = recommendation else {
            Issue.record("Expected a maintain recommendation")
            return
        }
        #expect(reason == "No skill level definition found.")
    }

    @Test("Counts only sessions at the current level")
    func insufficientCurrentLevelHistory() {
        let progression = makeProgression()
        let history = [
            makeEntry(level: 1, reps: 5, difficulty: .easy),
            makeEntry(level: 2, reps: 5, difficulty: .easy)
        ]

        guard case .maintain(let reason) = engine.evaluate(progression: progression, history: history) else {
            Issue.record("Expected a maintain recommendation")
            return
        }
        #expect(reason.contains("1 more session"))
    }

    @Test("Advances after the required successful sessions")
    func advancesAfterMeetingRepTarget() {
        let progression = makeProgression()
        let history = [
            makeEntry(dateOffset: 20, reps: 5, difficulty: .easy),
            makeEntry(dateOffset: 10, reps: 5, difficulty: .easy)
        ]

        guard case .advance(let level, _) = engine.evaluate(progression: progression, history: history) else {
            Issue.record("Expected an advance recommendation")
            return
        }
        #expect(level == 2)
    }

    @Test("Uses the most recent qualifying sessions regardless of input order")
    func sortsAndUsesMostRecentHistory() {
        let progression = makeProgression()
        let oldFailure = makeEntry(dateOffset: 30, reps: 1, difficulty: .hard)
        let recentSuccess = [
            makeEntry(dateOffset: 10, reps: 5, difficulty: .easy),
            makeEntry(dateOffset: 20, reps: 5, difficulty: .easy)
        ]

        guard case .advance = engine.evaluate(
            progression: progression,
            history: [recentSuccess[0], oldFailure, recentSuccess[1]]
        ) else {
            Issue.record("Expected old history outside the evaluation window to be ignored")
            return
        }
    }

    @Test("Regresses after two maximum-effort misses")
    func regressesAfterRepeatedMaxEffort() {
        let progression = makeProgression(currentLevel: 2)
        let history = [
            makeEntry(level: 2, reps: 1, difficulty: .maxEffort),
            makeEntry(level: 2, reps: 1, difficulty: .maxEffort)
        ]

        guard case .regress(let level, _) = engine.evaluate(progression: progression, history: history) else {
            Issue.record("Expected a regress recommendation")
            return
        }
        #expect(level == 1)
    }

    @Test("Does not regress below level one")
    func regressionFloor() {
        let progression = makeProgression()
        let history = [
            makeEntry(reps: 1, difficulty: .maxEffort),
            makeEntry(reps: 1, difficulty: .maxEffort)
        ]

        guard case .regress(let level, _) = engine.evaluate(progression: progression, history: history) else {
            Issue.record("Expected a regress recommendation")
            return
        }
        #expect(level == 1)
    }

    @Test("Requires every timed set to meet its duration")
    func timedSetsMustIndividuallyPass() {
        let progression = makeTimedProgression()
        let history = [
            makeEntry(durations: [30, 29], difficulty: .easy),
            makeEntry(durations: [30, 30], difficulty: .easy)
        ]

        guard case .maintain(let reason) = engine.evaluate(progression: progression, history: history) else {
            Issue.record("Expected a maintain recommendation")
            return
        }
        #expect(reason.contains("not every set met the target"))
    }

    @Test("Maintains at the final mastered level")
    func maintainsAtFinalLevel() {
        let progression = makeProgression(currentLevel: 2)
        let history = [
            makeEntry(level: 2, reps: 8, difficulty: .easy),
            makeEntry(level: 2, reps: 8, difficulty: .easy)
        ]

        guard case .maintain(let reason) = engine.evaluate(progression: progression, history: history) else {
            Issue.record("Expected a maintain recommendation")
            return
        }
        #expect(reason.contains("mastered all levels"))
    }

    @Test("Applying advance stamps achievement and preserves the input value")
    func appliesAdvance() {
        let progression = makeProgression()
        let updated = engine.apply(recommendation: .advance(to: 2, reason: "Ready"), to: progression)

        #expect(progression.currentLevel == 1)
        #expect(progression.levels[0].dateAchieved == nil)
        #expect(updated.currentLevel == 2)
        #expect(updated.levels[0].dateAchieved != nil)
    }

    @Test("Applying maintain leaves progression unchanged")
    func appliesMaintain() {
        let progression = makeProgression()
        let updated = engine.apply(recommendation: .maintain(reason: "Stay"), to: progression)

        #expect(updated.currentLevel == progression.currentLevel)
        #expect(updated.levels.allSatisfy { $0.dateAchieved == nil })
    }

    private func makeProgression(currentLevel: Int = 1) -> SkillProgression {
        SkillProgression(
            skillName: "Test Skill",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Foundation",
                    details: "",
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 2,
                        maxAverageDifficulty: 2.5,
                        minReps: 5
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Advanced",
                    details: "",
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 2,
                        maxAverageDifficulty: 2.5,
                        minReps: 8
                    )
                )
            ],
            currentLevel: currentLevel
        )
    }

    private func makeTimedProgression() -> SkillProgression {
        SkillProgression(
            skillName: "Timed Skill",
            levels: [
                SkillLevel(
                    level: 1,
                    name: "Hold",
                    details: "",
                    advanceCriteria: AdvanceCriteria(
                        consecutiveSessions: 2,
                        maxAverageDifficulty: 2.5,
                        minDurationSeconds: 30
                    )
                ),
                SkillLevel(
                    level: 2,
                    name: "Long Hold",
                    details: "",
                    advanceCriteria: AdvanceCriteria()
                )
            ]
        )
    }

    private func makeEntry(
        dateOffset: TimeInterval = 0,
        level: Int = 1,
        reps: Int = 5,
        difficulty: DifficultyRating
    ) -> SkillSessionEntry {
        SkillSessionEntry(
            date: Date(timeIntervalSinceReferenceDate: 10_000 - dateOffset),
            skillProgressionID: UUID(),
            level: level,
            sets: [
                CompletedSet(reps: reps, feltDifficulty: difficulty),
                CompletedSet(reps: reps, feltDifficulty: difficulty)
            ]
        )
    }

    private func makeEntry(
        durations: [Int],
        difficulty: DifficultyRating
    ) -> SkillSessionEntry {
        SkillSessionEntry(
            date: Date(),
            skillProgressionID: UUID(),
            level: 1,
            sets: durations.map { CompletedSet(durationSeconds: $0, feltDifficulty: difficulty) }
        )
    }
}

@Suite("Press Handstand progression")
struct PressHandstandProgressionTests {
    @Test("Introduces the weight-transfer drills before the elevated straddle press")
    func revisedOrder() {
        let levels = SkillProgressions.pressHandstand.levels

        #expect(levels.map(\.name) == [
            "Standing Straddle Compression / Foot Lifts",
            "Feet-Elevated Pike Weight Shift",
            "Feet-Elevated Pike Toe Float",
            "Feet-Elevated Straddle Toe Float",
            "Feet-Elevated Straddle Press Drill",
            "Wall Straddle Press Negative",
            "Floor Straddle Press Negative",
            "Partial Straddle Press",
            "Straddle Press Handstand"
        ])
        #expect(Set(levels.map(\.id)).count == levels.count)
    }

    @Test("Maps every legacy Press Handstand level to its matching revised stage")
    func legacyLevelMapping() {
        #expect(SkillProgressions.legacyPressHandstandLevelMap == [
            1: 4, 2: 5, 3: 6, 4: 7, 5: 8, 6: 9
        ])
    }
}

@Suite("Completed set metrics")
struct CompletedSetMetricTests {
    @Test func derivesHeartRateMetrics() {
        let end = Date(timeIntervalSinceReferenceDate: 100)
        let recovery = end.addingTimeInterval(20)
        let set = CompletedSet(
            endedAt: end,
            preSetHeartRate: 100,
            peakHeartRate: 165,
            recoveryHeartRate: 125,
            recoveryStartedAt: recovery
        )

        #expect(set.heartRateExcursion == 65)
        #expect(set.heartRateRecoveryDelta == 40)
        #expect(set.recoveryDuration == 20)
    }

    @Test func clampsNegativeRecoveryDuration() {
        let end = Date(timeIntervalSinceReferenceDate: 100)
        let set = CompletedSet(endedAt: end, recoveryStartedAt: end.addingTimeInterval(-5))

        #expect(set.recoveryDuration == 0)
    }
}

@Suite("Recovery score presentation")
struct RecoveryScorePresentationTests {
    @Test(arguments: [
        (90.0, "Excellent", "🟢"),
        (75.0, "Good", "🔵"),
        (60.0, "Moderate", "🟡"),
        (40.0, "Poor", "🟠"),
        (20.0, "Very Low", "🔴")
    ])
    func labelsAndEmoji(score: Double, label: String, emoji: String) {
        let result = RecoveryScore(
            overall: score,
            metrics: RecoveryMetrics(),
            dataQuality: .limited
        )

        #expect(result.label == label)
        #expect(result.emoji == emoji)
    }
}
