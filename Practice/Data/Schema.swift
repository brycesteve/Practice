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
    static var schemas: [any VersionedSchema.Type] { [
        TrainingSchemaV1.self,
        TrainingSchemaV2.self,
        TrainingSchemaV3.self
    ] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: TrainingSchemaV1.self, toVersion: TrainingSchemaV2.self),
         .lightweight(fromVersion: TrainingSchemaV2.self, toVersion: TrainingSchemaV3.self)]
    }  // add stages here for future versions
}

// MARK: - SwiftData Model Aliases

typealias CurrentSchema = TrainingSchemaV3
typealias BodyMeasurementRecord = TrainingSchemaV3.BodyMeasurementRecord
typealias WaistMeasurementRecord = TrainingSchemaV3.WaistMeasurementRecord
typealias BodyProfileSettings = TrainingSchemaV3.BodyProfileSettings
typealias WorkoutRecord = TrainingSchemaV2.WorkoutRecord
typealias ExerciseRecord = TrainingSchemaV2.ExerciseRecord
typealias SetRecord = TrainingSchemaV2.SetRecord
typealias SkillProgressionRecord = TrainingSchemaV2.SkillProgressionRecord
typealias SkillSessionRecord = TrainingSchemaV2.SkillSessionRecord
typealias SkillSetRecord = TrainingSchemaV2.SkillSetRecord
typealias KettlebellWeightRecord = TrainingSchemaV2.KettlebellWeightRecord
typealias AppSettings = TrainingSchemaV2.AppSettings
typealias RecoveryScoreRecord = TrainingSchemaV2.RecoveryScoreRecord
typealias RestDayRecord = TrainingSchemaV2.RestDayRecord
typealias ConditioningScoreRecord = TrainingSchemaV2.ConditioningScoreRecord

protocol CloudKitSchemaSeedable {
    static func makeSeed() -> any PersistentModel
    
}


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
        let container = try ModelContainer(
            for: schema,
            migrationPlan: TrainingMigrationPlan.self,
            configurations: config
        )
        Task {
            try await deduplicateProgressions(container: container)
            try await ensureDefaultProgressions(container: container)
        }
        return container
    }
    
    @MainActor
    private static func deduplicateProgressions(container: ModelContainer) throws {
        let records = try container.mainContext.fetch(FetchDescriptor<SkillProgressionRecord>())
        
        let grouped = Dictionary(grouping: records, by: { $0.skillName })
        
        for (_, duplicates) in grouped where duplicates.count > 1 {
            let keeper = duplicates.max(by: { $0.currentLevel < $1.currentLevel })!
            
            for record in duplicates where record != keeper {
                container.mainContext.delete(record)
            }
        }
        try container.mainContext.save()
    }
    
    @MainActor
    private static func ensureDefaultProgressions(container: ModelContainer) throws {
        let context = container.mainContext
        let existing = try context.fetch(FetchDescriptor<SkillProgressionRecord>())
        var byName: [String: SkillProgressionRecord] = Dictionary(
            grouping: existing,
            by: { $0.skillName }
        )
        .compactMapValues { $0.first }
        
        for def in SkillProgressions.defaultSkillProgressions {
            if let existing = byName[def.skillName] {
                if def.skillName == Skill.pressHandstand.rawValue,
                   SkillProgressions.isLegacyPressHandstand(existing.levels) {
                    try migrateLegacyPressHandstand(existing, in: context)
                } else {
                    existing.levels = def.levels
                }
            } else {
                let newRecord = SkillProgressionRecord(from: def)
                context.insert(newRecord)
                byName[def.skillName] = newRecord
            }
        }
        try context.save()
    }
    
    /// Preserves the meaning of sessions recorded against the original six-level path.
    /// The progression and session record UUIDs are never replaced; only their legacy
    /// numeric level references are translated before the new definitions are installed.
    @MainActor
    private static func migrateLegacyPressHandstand(
        _ progression: SkillProgressionRecord,
        in context: ModelContext
    ) throws {
        let previousLevels = progression.levels
        var revisedLevels = SkillProgressions.pressHandstand.levels

        for oldLevel in previousLevels {
            guard let revisedLevelNumber = SkillProgressions.legacyPressHandstandLevelMap[oldLevel.level],
                  let revisedIndex = revisedLevels.firstIndex(where: { $0.level == revisedLevelNumber }) else {
                continue
            }
            revisedLevels[revisedIndex].dateAchieved = oldLevel.dateAchieved
        }

        if let revisedCurrentLevel = SkillProgressions.legacyPressHandstandLevelMap[progression.currentLevel] {
            progression.currentLevel = revisedCurrentLevel
        }
        progression.levels = revisedLevels

        let progressionID = progression.id
        let sessions = try context.fetch(FetchDescriptor<SkillSessionRecord>())
        for session in sessions where session.skillProgressionID == progressionID {
            if let revisedLevel = SkillProgressions.legacyPressHandstandLevelMap[session.level] {
                session.level = revisedLevel
            }
        }
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


/// Disabled: the old implementation inserted diagnostic records into the user's live store.
/// Schema development must use a dedicated development store/account, never the app's container.
final class CloudKitSchemaPromotionEngine {
    enum PromotionError: Error { case liveStoreSeedingDisabled }
    @MainActor static func run(container: ModelContainer) throws {
        throw PromotionError.liveStoreSeedingDisabled
    }
}
