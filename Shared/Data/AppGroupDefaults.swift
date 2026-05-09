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
        let data = try? JSONEncoder().encode(data)
        defaults?.set(data, forKey: "appContext")
    }
    
    func loadAppContext() -> WCSyncPayload {
        guard let data = defaults?.data(forKey: "appContext"),
              let decoded = try? JSONDecoder().decode(WCSyncPayload.self, from: data) else {
            return WCSyncPayload()
        }
        
        return decoded
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
