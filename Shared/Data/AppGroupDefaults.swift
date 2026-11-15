//
//  AppGroupDefaults.swift
//  Practice
//
//  Created by Steve Bryce on 07/05/2026.
//

import Foundation

struct AppGroupDefaults {
    public static let shared = AppGroupDefaults()
    
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: "group.net.stevebryce.practice")) {
        self.defaults = defaults
    }
    
    // Watch-local preferences are independent of phone sync and never replace S&S settings.
    func strengthLoad(for key: String) -> Double? {
        guard let value = defaults?.object(forKey: "strengthLoad.\(key)") as? Double,
              value.isFinite, value > 0 else { return nil }
        return value
    }

    func saveStrengthLoad(_ weight: Double, for key: String) {
        guard weight.isFinite, weight > 0 else { return }
        defaults?.set(weight, forKey: "strengthLoad.\(key)")
    }

    func saveAppContext(_ data: WCSyncPayload) {
        var data = data
#if os(watchOS)
        let cached = loadAppContext()
        if (data.trainingHistoryUpdatedAt ?? .distantPast) < (cached.trainingHistoryUpdatedAt ?? .distantPast) {
            data.trainingHistory = cached.trainingHistory
            data.trainingHistoryUpdatedAt = cached.trainingHistoryUpdatedAt
        }
        let isPhoneSnapshot = data.trainingHistoryUpdatedAt != cached.trainingHistoryUpdatedAt
        let pendingIDs = Set(pendingTrainingCompletions().map(\.id))
        if !isPhoneSnapshot {
            let authoritativeIDs = Set(authoritativeTrainingHistory().map(\.id))
            data.trainingHistory.removeAll { pendingIDs.contains($0.id) && !authoritativeIDs.contains($0.id) }
        }
        let confirmedIDs = Set(data.trainingHistory.map(\.id))
        let pending = pendingTrainingCompletions().filter { !confirmedIDs.contains($0.id) }
        if let encoded = try? JSONEncoder().encode(pending) {
            defaults?.set(encoded, forKey: "pendingTrainingCompletions")
        }
        // Preserve a just-completed offline Watch session until the phone catches up.
        if let local = loadAppContext().lastEveningCompletion,
           local.date > (data.lastEveningCompletion?.date ?? .distantPast) {
            data.lastEveningCompletion = local
        }
#endif
        data.eveningRotationDay = EveningRotation.nextIndex(after: data.lastEveningCompletion, fallback: data.eveningRotationDay)
        let encoded = try? JSONEncoder().encode(data)
        defaults?.set(encoded, forKey: "appContext")
        defaults?.synchronize()
    }
    
    func loadAppContext() -> WCSyncPayload {
        var value = defaults?.data(forKey: "appContext")
            .flatMap { try? JSONDecoder().decode(WCSyncPayload.self, from: $0) } ?? WCSyncPayload()
#if os(watchOS)
        let ids = Set(value.trainingHistory.map(\.id))
        value.trainingHistory = DailyPractice.ordered(value.trainingHistory + pendingTrainingCompletions().filter { !ids.contains($0.id) })
#endif
        if let recovery = value.recoveryData, !RecoveryAggregation.isConsistent(recovery) { value.recoveryData = nil }
        value.eveningRotationDay = EveningRotation.nextIndex(after: value.lastEveningCompletion, fallback: value.eveningRotationDay)
        return value
    }
    
    private func authoritativeTrainingHistory() -> [TrainingCompletion] {
        guard let data = defaults?.data(forKey: "appContext"),
              let context = try? JSONDecoder().decode(WCSyncPayload.self, from: data) else { return [] }
        return context.trainingHistory
    }

    private func pendingTrainingCompletions() -> [TrainingCompletion] {
        guard let data = defaults?.data(forKey: "pendingTrainingCompletions") else { return [] }
        return (try? JSONDecoder().decode([TrainingCompletion].self, from: data)) ?? []
    }

    func recordTrainingCompletion(_ workout: CompletedWorkout) {
        let cached = loadAppContext()
        guard !cached.trainingHistory.contains(where: { $0.id == workout.id }),
              let completion = DailyPractice.completion(for: workout, history: cached.trainingHistory,
            progressions: cached.skillProgressions + SkillProgressions.defaultSkillProgressions) else { return }
        var pending = pendingTrainingCompletions().filter { $0.id != completion.id }
        pending.append(completion)
        if let data = try? JSONEncoder().encode(pending) { defaults?.set(data, forKey: "pendingTrainingCompletions") }
    }

    func updateRestDays(_ days: [Date]) {
        var data = loadAppContext()
        data.updateRestDays(days)
        saveAppContext(data)
    }
    
    func addSkillProgression(_ progression: SkillProgression) {
        var data = loadAppContext()
        data.addSkillProgression(progression)
        saveAppContext(data)
        
    }
    
    func updateSkillProgressions(_ progressions: [SkillProgression]) {
        var data = loadAppContext()
        data.skillProgressions = progressions
        saveAppContext(data)
    }
    
    func updateRotationDay(_ day: Int) {
        var data = loadAppContext()
        data.eveningRotationDay = day
        saveAppContext(data)
    }
    
    func updateKettlebellTargets(swing: Double, tgu: Double) {
        var data = loadAppContext()
        data.targetSwingWeightKg = swing
        data.targetTGUWeightKg = tgu
        saveAppContext(data)
    }
    
    func updateKettlebellPlan(
        currentSwing: Double,
        currentTGU: Double,
        progressionSwing: Double,
        progressionTGU: Double,
        swingProgressionSets: Int,
        tguProgressionSets: Int
    ) {
        var data = loadAppContext()
        data.currentSwingWeightKg = currentSwing
        data.currentTGUWeightKg = currentTGU
        data.swingProgressionWeightKg = progressionSwing
        data.tguProgressionWeightKg = progressionTGU
        data.swingProgressionSetCount = swingProgressionSets
        data.tguProgressionSetCount = tguProgressionSets
        saveAppContext(data)
    }
    
    func updateLastTGUWeight(_ weight: Double) {
        var data = loadAppContext()
        data.lastTGUWeightKg = weight
        saveAppContext(data)
    }
   
    func updateLastSwingWeight(_ weight: Double) {
        var data = loadAppContext()
        data.lastSwingWeightKg = weight
        saveAppContext(data)
    }
    
    
    
    public static var menSimple:   (swing: Double, tgu: Double) { (32, 32) }
    public static var womenSimple: (swing: Double, tgu: Double) { (24, 16) }
}
