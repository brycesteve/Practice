import Foundation
import SwiftData
import Testing
@testable import Practice

@Suite("Body SwiftData persistence")
@MainActor
struct BodyPersistenceTests {
    private func raw() throws -> RawBodyMeasurement {
        RawBodyMeasurement(weightKg: 67.8, impedanceOhms: 529, impedanceMetadata: 0x1234,
            scale: try #require(ScaleIdentifier(companyID: 0xA0AC, macAddress: "A0:91:5B:35:E2:A8")),
            profile: .init(heightCm: 172, age: 47, calculationSex: .male, waistCm: 85))
    }

    @Test func duplicateDeliveryPersistsExactlyOneRawMeasurement() throws {
        let schema = Schema(CurrentSchema.models)
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let measurement = try raw()
        try BodyMeasurementStore.insert(measurement, into: container)
        try BodyMeasurementStore.insert(measurement, into: container)
        let records = try container.mainContext.fetch(FetchDescriptor<BodyMeasurementRecord>())
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.rawMeasurement == measurement)
        #expect(record.impedanceMetadata == 0x1234)
        #expect(record.composition.bodyFatPercentage?.algorithmVersion == 1)
        #expect(record.healthExportedTypes.isEmpty)
    }

    @Test func invalidMeasurementIsNotAcknowledgedAsSaved() throws {
        let schema = Schema(CurrentSchema.models)
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        var measurement = try raw()
        measurement.weightKg = -1
        #expect(throws: (any Error).self) {
            try BodyMeasurementStore.insert(measurement, into: container)
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<BodyMeasurementRecord>()) == 0)
    }

    @Test func profileAndWaistPersistIndependentlyOfScaleMeasurements() throws {
        let schema = Schema(CurrentSchema.models)
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let settings = BodyProfileSettings()
        var configuration = BodyConfiguration()
        configuration.heightCm = 172
        configuration.calculationSex = .male
        settings.configuration = configuration
        context.insert(settings)
        context.insert(try WaistMeasurementRecord(circumferenceCm: 85, heightCm: 172))
        try context.save()
        #expect(try BodyMeasurementStore.configuration(in: context) == configuration)
        #expect(try context.fetchCount(FetchDescriptor<WaistMeasurementRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<BodyMeasurementRecord>()) == 0)
    }

    @Test func v2StoreMigratesAndPreservesExistingSettings() throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("migration.store")
        try createV2Store(at: url)
        let schema = Schema(CurrentSchema.models)
        let container = try ModelContainer(for: schema, migrationPlan: TrainingMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let settings = try #require(container.mainContext.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(settings.eveningRotationDay == 2)
        #expect(settings.currentSwingWeightKg == 28)
        try BodyMeasurementStore.insert(try raw(), into: container)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<BodyMeasurementRecord>()) == 1)
    }

    private func createV2Store(at url: URL) throws {
        let schema = Schema(TrainingSchemaV2.models)
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let settings = TrainingSchemaV2.AppSettings()
        settings.eveningRotationDay = 2
        settings.currentSwingWeightKg = 28
        container.mainContext.insert(settings)
        try container.mainContext.save()
    }
}
