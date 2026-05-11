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
        TrainingSchemaV1.self
    ] }
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
typealias ConditioningScoreRecord = CurrentSchema.ConditioningScoreRecord

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
            try await ensureDefaultProgressions(container: container)
        }
        return container
    }
    
    @MainActor private static func ensureDefaultProgressions(container: ModelContainer) throws {
        let desc = FetchDescriptor<SkillProgressionRecord>()
        let progressions = try container.mainContext.fetch(desc)
        let existingNames = Set(progressions.map { $0.skillName })
        for def in SkillProgressions.defaultSkillProgressions {
            if !existingNames.contains(def.skillName) {
                container.mainContext.insert(SkillProgressionRecord(from: def))
            }
            else if let progression = progressions.first(where: { p in
                p.skillName == def.skillName
            }) {
                progression.levels = def.levels
            }
        }
        try? container.mainContext.save()
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


final class CloudKitSchemaPromotionEngine {
    @MainActor static func run(container: ModelContainer) {
        let context = container.mainContext
        var inserted: [any PersistentModel] = []
        
        for type in CurrentSchema.models {
            guard let seedType = type as? CloudKitSchemaSeedable.Type else {
                continue
            }
            
            let seed = seedType.makeSeed()
            context.insert(seed)
            inserted.append(seed)
        }
        
        do {
            try context.save()
            print("✅ Seed data saved — CloudKit schema should now be materialised")
        } catch {
            print("❌ Schema bootstrap failed: \(error)")
            return
        }
        
        print("""
        📦 Schema Promotion Complete (Development):
        ✔ All record types exercised
        ✔ CloudKit schema will now appear in dashboard
        ✔ Safe to inspect and deploy to Production
        👉 Next step: CloudKit Dashboard → Deploy Schema Changes
        """)
        //Self.cleanup(context: context, inserted: inserted)
    }
    
    static func cleanup(context: ModelContext, inserted: [any PersistentModel]) {
        inserted.forEach { context.delete($0) }
        try? context.save()
        
    }
}
