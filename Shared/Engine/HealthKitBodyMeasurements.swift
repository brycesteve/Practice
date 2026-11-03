import Foundation
import HealthKit

extension HealthKitManager {
    /// Resolve inputs independently. HealthKit read denial is deliberately indistinguishable
    /// from no data; only the user-provided fallback fills missing values.
    func bodyProfile(fallback: BodyConfiguration, at date: Date = .now) async -> BodyProfileSnapshot {
        var profile = fallback.fallbackProfile(at: date)
        if let sample = try? await latestBodyQuantity(.height, at: date) {
            let cm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            if cm.isFinite && cm > 0 {
                profile.heightCm = cm
                profile.heightSource = "HealthKit"
            }
        }
        if let components = try? store.dateOfBirthComponents(),
           let birth = Calendar.current.date(from: components),
           let age = Calendar.current.dateComponents([.year], from: birth, to: date).year,
           age >= 0 {
            profile.age = age
            profile.ageSource = "HealthKit date of birth"
        }
        if let sex = try? fetchBiologicalSex() {
            switch sex {
            case .male:
                profile.calculationSex = .male
                profile.sexSource = "HealthKit"
            case .female:
                profile.calculationSex = .female
                profile.sexSource = "HealthKit"
            case .other, .notSet:
                break // Explicit user selection, if any, is retained. Never infer a coefficient.
            }
        }
        if let sample = try? await latestBodyQuantity(.waistCircumference, at: date) {
            let cm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            if cm.isFinite && cm > 0 {
                profile.waistCm = cm
                profile.waistDate = sample.startDate
                profile.waistSource = "HealthKit"
            }
        }
        return profile
    }

    private func latestBodyQuantity(_ identifier: HKQuantityTypeIdentifier, at date: Date) async throws -> HKQuantitySample? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier),
                predicate: HKQuery.predicateForSamples(withStart: nil, end: date))],
            sortDescriptors: [SortDescriptor(\HKQuantitySample.startDate, order: .reverse)],
            limit: 1)
        return try await descriptor.result(for: store).first
    }

    /// The phone is the sole writer. Stable per-measurement/type sync identifiers make
    /// retries safe even if HealthKit succeeded but updating SwiftData subsequently failed.
    /// Returns only types that were authorised and saved. Denied types remain retryable.
    func writeBodyMeasurement(_ raw: RawBodyMeasurement, excluding: Set<String> = []) async throws -> [String] {
        guard raw.isValid else { return [] }
        let composition = KushnerSchoellerCalculator().calculate(weightKg: raw.weightKg,
            impedanceOhms: raw.impedanceOhms, profile: raw.profile)
        var samples: [HKQuantitySample] = []
        func append(_ type: HKQuantityTypeIdentifier, value: Double, unit: HKUnit, estimate: BodyEstimate? = nil) {
            let quantityType = HKQuantityType(type)
            guard !excluding.contains(type.rawValue),
                  store.authorizationStatus(for: quantityType) == .sharingAuthorized else { return }
            var metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "Practice.body.\(raw.id.uuidString).\(type.rawValue)",
                HKMetadataKeySyncVersion: 1
            ]
            if let estimate {
                metadata["PracticeCalculationMethod"] = estimate.method
                metadata["PracticeAlgorithmVersion"] = estimate.algorithmVersion
                metadata["PracticeIsEstimate"] = true
                metadata["PracticeHeightCm"] = raw.profile.heightCm
                metadata["PracticeAgeYears"] = raw.profile.age
                metadata["PracticeCalculationSex"] = raw.profile.calculationSex?.rawValue
                metadata["PracticeImpedanceOhms"] = raw.impedanceOhms
            }
            samples.append(HKQuantitySample(type: quantityType, quantity: HKQuantity(unit: unit, doubleValue: value),
                start: raw.date, end: raw.date, metadata: metadata))
        }
        append(.bodyMass, value: raw.weightKg, unit: .gramUnit(with: .kilo))
        if let estimate = composition.bodyFatPercentage {
            append(.bodyFatPercentage, value: estimate.value / 100, unit: .percent(), estimate: estimate)
        }
        if let estimate = composition.fatFreeMassKg {
            append(.leanBodyMass, value: estimate.value, unit: .gramUnit(with: .kilo), estimate: estimate)
        }
        // BMI is displayed in Practice; the existing HealthKit strategy has no BMI writes.
        // Waist is exported only for a NEW manual waist entry, never copied from HealthKit.
        guard !samples.isEmpty else { return [] }
        try await store.save(samples)
        return samples.map { $0.quantityType.identifier }
    }

    func writeWaist(id: UUID, date: Date, circumferenceCm: Double) async throws -> Bool {
        let type = HKQuantityType(.waistCircumference)
        guard circumferenceCm.isFinite, circumferenceCm > 0,
              store.authorizationStatus(for: type) == .sharingAuthorized else { return false }
        let sample = HKQuantitySample(type: type,
            quantity: HKQuantity(unit: .meterUnit(with: .centi), doubleValue: circumferenceCm),
            start: date, end: date, metadata: [
                HKMetadataKeySyncIdentifier: "Practice.waist.\(id.uuidString)",
                HKMetadataKeySyncVersion: 1,
                HKMetadataKeyWasUserEntered: true
            ])
        try await store.save(sample)
        return true
    }
}
