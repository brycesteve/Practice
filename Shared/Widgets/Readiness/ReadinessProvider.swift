
//
//  ReadinessEntry.swift
//  Practice
//
//  Created by Steve Bryce on 16/08/2025.
//


import WidgetKit
import SwiftUI

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let readinessScore: Int
    let isStale: Bool
}

struct ReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: .now, readinessScore: 75, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        let snapshot = readEntry()
        completion(snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let entry = readEntry()
        let next = nextUpdateDate(avoidSleepWindow: true)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readEntry() -> ReadinessEntry {
        if let loaded = SharedReadinessStore.load() {
            // Mark stale if older than e.g. 12 hours
            let isStale = Date().timeIntervalSince(loaded.date) > 60 * 60 * 2
            return ReadinessEntry(date: .now, readinessScore: loaded.score, isStale: isStale)
            
        } else {
            return ReadinessEntry(date: .now, readinessScore: 0, isStale: true)
        }
    }

    private func nextUpdateDate(avoidSleepWindow: Bool) -> Date {
        let now = Date()
        guard avoidSleepWindow else { return now.addingTimeInterval(60 * 30) }

        let cal = Calendar.current
        let todays10pm = cal.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
        let tomorrow510 = cal.date(bySettingHour: 5, minute: 10, second: 0, of: now.addingTimeInterval(86400))!

        if now >= todays10pm {
            return tomorrow510 // overnight → next morning
        } else if now < cal.date(bySettingHour: 5, minute: 10, second: 0, of: now)! {
            // before 5:10 today → set to 5:10 today
            return cal.date(bySettingHour: 5, minute: 10, second: 0, of: now)!
        } else {
            // daytime: periodic refresh
            return now.addingTimeInterval(60 * 30)
        }
    }
}
