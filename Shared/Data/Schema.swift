// Schema.swift — TrainingShared
//
// SwiftData @Model classes.
//
// Storage strategy:
//   iOS  → SwiftData + CloudKit (.cloudKitDatabase: .automatic)
//          Provides iCloud backup and sync automatically.
//   watchOS → SwiftData local only (plain ModelConfiguration)
//             WatchConnectivity is the real-time bridge; CloudKit sync
//             on watchOS is slow and unnecessary given WC handles it.
//


import Foundation
import SwiftData

// MARK: - Migration

/// Lightweight migration plan — register new versions here as the schema evolves.
/// SwiftData will apply lightweight migrations automatically for additive changes
/// (new optional properties, new models). Register a custom stage here for any
/// breaking change (renamed properties, removed models, changed relationships).
enum TrainingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TrainingSchemaV1.self] }
    static var stages: [MigrationStage] { [] }  // add stages here for future versions
}

// MARK: - SwiftData Model Aliases

typealias CurrentSchema = TrainingSchemaV1
typealias WorkoutRecord = CurrentSchema.WorkoutRecord
typealias ExerciseRecord = CurrentSchema.ExerciseRecord
typealias SetRecord = CurrentSchema.SetRecord
typealias SkillProgressionRecord = CurrentSchema.SkillProgressionRecord
typealias SkillSessionRecord = CurrentSchema.SkillSessionRecord
typealias SkillSetRecord = CurrentSchema.SkillSetRecord
typealias KettlebellWeightRecord = CurrentSchema.KettlebellWeightRecord
typealias AppSettings = CurrentSchema.AppSettings
typealias RecoveryScoreRecord = CurrentSchema.RecoveryScoreRecord
typealias RestDayRecord = CurrentSchema.RestDayRecord


// MARK: - Container factory

public extension ModelContainer {
    
    /// iOS container — syncs with CloudKit for backup and cross-device persistence.
    /// Call this from TrainingApp (iOS target only).
    static func makeiOS() throws -> ModelContainer {
        let schema = Schema(CurrentSchema.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: TrainingMigrationPlan.self,
            configurations: config
        )
    }
    
    /// watchOS container — local only. WatchConnectivity is the sync bridge.
    /// Call this from TrainingWatchApp (watchOS target only).
    static func makeWatch() throws -> ModelContainer {
        let schema = Schema(CurrentSchema.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: TrainingMigrationPlan.self,
            configurations: config
        )
    }
   
    
}
