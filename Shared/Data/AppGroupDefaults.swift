//
//  AppGroupDefaults.swift
//  Practice
//
//  Created by Steve Bryce on 07/05/2026.
//

import Foundation

struct AppGroupDefaults {
    public static let shared = AppGroupDefaults()
    
    private let defaults = UserDefaults(suiteName: "group.net.stevebryce.practice")
    
    func saveAppContext(_ data: WCSyncPayload) {
        var data = data
#if os(watchOS)
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
        guard let data = defaults?.data(forKey: "appContext"),
              let decoded = try? JSONDecoder().decode(WCSyncPayload.self, from: data) else {
            return WCSyncPayload()
        }
        
        var value = decoded
        if let recovery = value.recoveryData, !RecoveryAggregation.isConsistent(recovery) { value.recoveryData = nil }
        value.eveningRotationDay = EveningRotation.nextIndex(after: value.lastEveningCompletion, fallback: value.eveningRotationDay)
        return value
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
