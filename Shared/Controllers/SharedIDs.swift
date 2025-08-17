//
//  SharedIDs.swift
//  Practice
//
//  Created by Steve Bryce on 16/08/2025.
//


// Shared between iOS app, watch app, and widget extension
import Foundation
import WidgetKit

enum SharedIDs {
    static let appGroup = "group.net.stevebryce.practice" // <— change to yours
    static let readinessScoreKey = "readinessScore"
    static let readinessDateKey  = "readinessDate"
}

struct SharedReadinessStore {
    static let defaults = UserDefaults(suiteName: SharedIDs.appGroup)!

    static func save(score: Int, date: Date = .now) {
        defaults.set(score, forKey: SharedIDs.readinessScoreKey)
        defaults.set(date,  forKey: SharedIDs.readinessDateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> (score: Int, date: Date)? {
        guard let date = defaults.object(forKey: SharedIDs.readinessDateKey) as? Date else { return nil }
        let score = defaults.integer(forKey: SharedIDs.readinessScoreKey)
        return (score, date)
    }
}
