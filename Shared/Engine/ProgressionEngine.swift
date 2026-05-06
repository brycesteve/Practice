// ProgressionEngine.swift — TrainingShared
// Adaptive logic: analyses recent skill session history and recommends level changes

import Foundation

public enum ProgressionRecommendation: Sendable {
    case advance(to: Int, reason: String)
    case maintain(reason: String)
    case regress(to: Int, reason: String)
}

public struct ProgressionEngine: Sendable {
    
    public init() {}
    
    /// Evaluate the most recent history for a skill and return a recommendation.
    /// - Parameters:
    ///   - progression: The current SkillProgression (includes currentLevel)
    ///   - history: All SkillSessionEntry records for this progression, sorted oldest→newest
    public func evaluate(
        progression: SkillProgression,
        history: [SkillSessionEntry]
    ) -> ProgressionRecommendation {
        
        guard let currentLevelDef = progression.currentSkillLevel else {
            return .maintain(reason: "No skill level definition found.")
        }
        
        let criteria = currentLevelDef.advanceCriteria
        let recentHistory = history
            .filter { $0.level == progression.currentLevel }
            .sorted { $0.date < $1.date }
            .suffix(criteria.consecutiveSessions)   // look at the most recent N sessions
        
        // Not enough data yet
        guard recentHistory.count >= criteria.consecutiveSessions else {
            let remaining = criteria.consecutiveSessions - recentHistory.count
            return .maintain(reason: "Need \(remaining) more session(s) at this level before evaluating.")
        }
        
        // Check if all recent sessions meet the performance criteria
        var allMeetTarget = true
        var allEasyEnough = true
        
        for entry in recentHistory {
            // Difficulty check
            if entry.averageDifficulty > criteria.maxAverageDifficulty {
                allEasyEnough = false
            }
            
            // Performance check
            if let minReps = criteria.minReps {
                let totalReps = entry.sets.compactMap(\.reps).reduce(0, +)
                if totalReps < minReps * entry.sets.count {
                    allMeetTarget = false
                }
            }
            
            if let minDur = criteria.minDurationSeconds {
                // Each set must meet minimum duration
                for s in entry.sets {
                    if (s.durationSeconds ?? 0) < minDur { allMeetTarget = false }
                }
            }
        }
        
        // Regress check: if the last 2 sessions were both max effort, consider stepping back
        let lastTwo = Array(recentHistory.suffix(2))
        let allMaxEffort = lastTwo.count == 2 && lastTwo.allSatisfy { $0.averageDifficulty >= 4.5 }
        
        if allMaxEffort && !allMeetTarget {
            let regressionLevel = max(1, progression.currentLevel - 1)
            return .regress(
                to: regressionLevel,
                reason: "Recent sessions show maximum effort without meeting targets. Consolidating at level \(regressionLevel)."
            )
        }
        
        if allMeetTarget && allEasyEnough {
            if let next = progression.nextSkillLevel {
                return .advance(
                    to: next.level,
                    reason: "You've hit the target for \(criteria.consecutiveSessions) consecutive sessions with manageable effort. Ready for \(next.name)! 🎉"
                )
            } else {
                return .maintain(reason: "You've mastered all levels. Incredible work! 🏆")
            }
        }
        
        // Build a helpful maintenance message
        let avgDiff = recentHistory.map(\.averageDifficulty).reduce(0, +) / Double(recentHistory.count)
        let difficultyNote = allEasyEnough ? "" : " (avg difficulty \(String(format: "%.1f", avgDiff)) — still feels tough)"
        return .maintain(reason: "Keep building consistency at this level\(difficultyNote). \(criteria.consecutiveSessions - recentHistory.count) more qualifying session(s) needed.")
    }
    
    /// Apply a recommendation to a progression, returning an updated copy.
    /// Stamps dateAchieved on the level being left when advancing.
    public func apply(
        recommendation: ProgressionRecommendation,
        to progression: SkillProgression
    ) -> SkillProgression {
        var updated = progression
        switch recommendation {
        case .advance(let level, _):
            // Mark the current level as achieved before moving up
            if let idx = updated.levels.firstIndex(where: { $0.level == updated.currentLevel }) {
                updated.levels[idx].dateAchieved = Date()
            }
            updated.currentLevel = level
        case .regress(let level, _):
            updated.currentLevel = level
        case .maintain:
            break
        }
        return updated
    }
}
