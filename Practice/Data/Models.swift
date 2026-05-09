//
//  Models.swift
//  Practice
//
//  Created by Steve Bryce on 07/05/2026.
//

import Foundation



extension KettlebellEntryTransfer {
    /// Construct the SwiftData model — call only on the main actor.
    @MainActor
    func toRecord() -> KettlebellWeightRecord {
        KettlebellWeightRecord(
            id: id, date: date,
            exerciseType: exerciseType,
            weightKg: weightKg, sets: sets, reps: reps
        )
    }
}
