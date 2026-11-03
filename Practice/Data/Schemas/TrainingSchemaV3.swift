import Foundation
import SwiftData

/// Additive schema. Existing V2 model identities and stored properties are unchanged.
enum TrainingSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        TrainingSchemaV2.models + [BodyMeasurementRecord.self, WaistMeasurementRecord.self, BodyProfileSettings.self]
    }

    @Model
    final class BodyMeasurementRecord: CloudKitSchemaSeedable {
        var id: UUID = UUID()
        var date: Date = Date()
        var weightKg: Double = 0
        var impedanceOhms: Double?
        var impedanceMetadata: Int?
        var companyID: Int = 0
        var scaleMAC: String = ""
        /// Immutable input snapshot makes estimates reproducible without storing body fat as truth.
        var profileData: Data?
        var healthExportError: String?
        var healthExportedTypes: [String] = []

        init(_ raw: RawBodyMeasurement) throws {
            id = raw.id
            date = raw.date
            weightKg = raw.weightKg
            impedanceOhms = raw.impedanceOhms
            impedanceMetadata = raw.impedanceMetadata.map(Int.init)
            companyID = Int(raw.scale.companyID)
            scaleMAC = raw.scale.macAddress
            profileData = try JSONEncoder().encode(raw.profile)
        }

        var profile: BodyProfileSnapshot {
            guard let profileData, let value = try? JSONDecoder().decode(BodyProfileSnapshot.self, from: profileData) else { return .init() }
            return value
        }

        var rawMeasurement: RawBodyMeasurement? {
            guard let company = UInt16(exactly: companyID),
                  let scale = ScaleIdentifier(companyID: company, macAddress: scaleMAC) else { return nil }
            return RawBodyMeasurement(id: id, date: date, weightKg: weightKg,
                impedanceOhms: impedanceOhms, impedanceMetadata: impedanceMetadata.flatMap(UInt16.init(exactly:)),
                scale: scale, profile: profile)
        }

        var composition: BodyCompositionResult {
            KushnerSchoellerCalculator().calculate(weightKg: weightKg, impedanceOhms: impedanceOhms, profile: profile)
        }

        static func makeSeed() -> any PersistentModel {
            // Seed is only used by the existing explicit development schema-promotion action.
            let seed = BodyMeasurementRecord()
            return seed
        }

        private init() {}
    }

    @Model
    final class WaistMeasurementRecord {
        var id: UUID = UUID()
        var date: Date = Date()
        var circumferenceCm: Double = 0
        var heightCm: Double?
        var healthExported: Bool = false
        var healthExportError: String?

        init(date: Date = .now, circumferenceCm: Double, heightCm: Double? = nil) throws {
            guard circumferenceCm.isFinite, circumferenceCm > 0 else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }
            self.date = date
            self.circumferenceCm = circumferenceCm
            self.heightCm = heightCm
        }


    }

    @Model
    final class BodyProfileSettings: CloudKitSchemaSeedable {
        var id: UUID = UUID()
        var heightCm: Double?
        var dateOfBirth: Date?
        var calculationSexRaw: String?
        var scaleCompanyID: Int?
        var scaleMAC: String?
        init() {}

        var configuration: BodyConfiguration {
            get {
                var value = BodyConfiguration()
                value.heightCm = heightCm
                value.dateOfBirth = dateOfBirth
                value.calculationSex = calculationSexRaw.flatMap(BodyCalculationSex.init(rawValue:))
                if let company = scaleCompanyID.flatMap(UInt16.init(exactly:)), let scaleMAC {
                    value.scale = ScaleIdentifier(companyID: company, macAddress: scaleMAC)
                }
                return value
            }
            set {
                heightCm = newValue.heightCm
                dateOfBirth = newValue.dateOfBirth
                calculationSexRaw = newValue.calculationSex?.rawValue
                scaleCompanyID = newValue.scale.map { Int($0.companyID) }
                scaleMAC = newValue.scale?.macAddress
            }
        }

        static func makeSeed() -> any PersistentModel { BodyProfileSettings() }
    }
}
