import Foundation
import SwiftData

@MainActor
enum BodyMeasurementStore {
    static func configuration(in context: ModelContext) throws -> BodyConfiguration {
        try context.fetch(FetchDescriptor<BodyProfileSettings>()).first?.configuration ?? .init()
    }

    /// Called on the main actor, with no suspension between lookup and save.
    /// A dedicated context prevents a failed import from rolling back unrelated UI edits.
    @discardableResult
    static func insert(_ raw: RawBodyMeasurement, into container: ModelContainer) throws -> UUID {
        guard raw.isValid else { throw CocoaError(.validationMissingMandatoryProperty) }
        let context = ModelContext(container)
        let id = raw.id
        if try context.fetch(FetchDescriptor<BodyMeasurementRecord>(predicate: #Predicate { $0.id == id })).isEmpty {
            context.insert(try BodyMeasurementRecord(raw))
            try context.save()
        }
        return id
    }

    static func resolveProfile(configuration: BodyConfiguration, at date: Date, in context: ModelContext) async -> BodyProfileSnapshot {
        var profile = await HealthKitManager.shared.bodyProfile(fallback: configuration, at: date)
        if let waist = try? latestValidWaist(in: context, at: date),
           waist.date >= (profile.waistDate ?? .distantPast) {
            profile.waistCm = waist.circumferenceCm
            profile.waistDate = waist.date
            profile.waistSource = "Manual measurement"
        }
        return profile
    }

    static func latestValidWaist(in context: ModelContext, at date: Date) throws -> WaistMeasurementRecord? {
        let descriptor = FetchDescriptor<WaistMeasurementRecord>(
            predicate: #Predicate { $0.date <= date && $0.circumferenceCm > 0 },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).first { $0.circumferenceCm.isFinite }
    }

    @discardableResult
    static func insertWaist(date: Date, circumferenceCm: Double, heightCm: Double?,
                            into context: ModelContext) throws -> WaistMeasurementRecord {
        let record = try WaistMeasurementRecord(date: date, circumferenceCm: circumferenceCm, heightCm: heightCm)
        context.insert(record)
        do { try context.save() } catch { context.delete(record); throw error }
        return record
    }

    /// Supplement only missing inputs; previously computed estimates remain reproducible.
    static func fillMissingProfile(_ record: BodyMeasurementRecord, in context: ModelContext) async throws {
        let configuration = try configuration(in: context)
        let resolved = await resolveProfile(configuration: configuration, at: record.date, in: context)
        var profile = record.profile
        if profile.heightCm == nil {
            profile.heightCm = resolved.heightCm
            profile.heightSource = resolved.heightSource
        }
        if profile.age == nil {
            profile.age = resolved.age
            profile.ageSource = resolved.ageSource
        }
        if profile.calculationSex == nil {
            profile.calculationSex = resolved.calculationSex
            profile.sexSource = resolved.sexSource
        }
        if profile.waistCm == nil {
            profile.waistCm = resolved.waistCm
            profile.waistDate = resolved.waistDate
            profile.waistSource = resolved.waistSource
        }
        let previous = record.profileData
        record.profileData = try JSONEncoder().encode(profile)
        do { try context.save() } catch { record.profileData = previous; throw error }
    }

    static func export(_ record: BodyMeasurementRecord, in context: ModelContext) async {
        guard let raw = record.rawMeasurement else { return }
        do {
            let written = try await HealthKitManager.shared.writeBodyMeasurement(raw, excluding: Set(record.healthExportedTypes))
            record.healthExportedTypes = Array(Set(record.healthExportedTypes + written)).sorted()
            record.healthExportError = nil
            try context.save()
        } catch {
            record.healthExportError = error.localizedDescription
            try? context.save()
        }
    }

    static func exportWaist(_ record: WaistMeasurementRecord, in context: ModelContext) async {
        guard record.circumferenceCm.isFinite, record.circumferenceCm > 0, !record.healthExported else { return }
        do {
            record.healthExported = try await HealthKitManager.shared.writeWaist(id: record.id,
                date: record.date, circumferenceCm: record.circumferenceCm)
            record.healthExportError = nil
            try context.save()
        } catch {
            record.healthExportError = error.localizedDescription
            try? context.save()
        }
    }

    static func retryHealthExports(in context: ModelContext) async {
        guard let records = try? context.fetch(FetchDescriptor<BodyMeasurementRecord>()),
              let waists = try? context.fetch(FetchDescriptor<WaistMeasurementRecord>()) else { return }
        for record in records { await export(record, in: context) }
        for waist in waists { await exportWaist(waist, in: context) }
    }
}
