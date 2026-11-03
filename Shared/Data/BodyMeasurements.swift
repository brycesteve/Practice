import Foundation

public enum BodyCalculationSex: String, Codable, CaseIterable, Sendable {
    case male, female
}

/// Optional inputs: absent HealthKit data must never become an invented profile.
public struct BodyProfileSnapshot: Codable, Equatable, Sendable {
    public var heightCm: Double?
    public var age: Int?
    public var calculationSex: BodyCalculationSex?
    public var waistCm: Double?
    public var waistDate: Date?
    public var heightSource: String?
    public var ageSource: String?
    public var sexSource: String?
    public var waistSource: String?

    public init(heightCm: Double? = nil, age: Int? = nil,
                calculationSex: BodyCalculationSex? = nil, waistCm: Double? = nil) {
        self.heightCm = heightCm
        self.age = age
        self.calculationSex = calculationSex
        self.waistCm = waistCm
    }
}

public struct BodyConfiguration: Codable, Equatable, Sendable {
    public var heightCm: Double?
    public var dateOfBirth: Date?
    public var calculationSex: BodyCalculationSex?
    public var scale: ScaleIdentifier?

    public init() {}

    public func fallbackProfile(at date: Date) -> BodyProfileSnapshot {
        var result = BodyProfileSnapshot(heightCm: heightCm,
            age: dateOfBirth.flatMap { Calendar.current.dateComponents([.year], from: $0, to: date).year },
            calculationSex: calculationSex)
        if heightCm != nil { result.heightSource = "Manual fallback" }
        if dateOfBirth != nil { result.ageSource = "Manual fallback" }
        if calculationSex != nil { result.sexSource = "User-selected calculation model" }
        return result
    }
}

/// Canonical observations. Estimates are computed independently and never replace these.
public struct RawBodyMeasurement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var weightKg: Double
    /// Whole ohms inferred from physical experiments, not manufacturer documentation.
    public var impedanceOhms: Double?
    public var impedanceMetadata: UInt16?
    public var scale: ScaleIdentifier
    public var profile: BodyProfileSnapshot

    public init(id: UUID = UUID(), date: Date = .now, weightKg: Double,
                impedanceOhms: Double? = nil, impedanceMetadata: UInt16? = nil,
                scale: ScaleIdentifier, profile: BodyProfileSnapshot = .init()) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.impedanceOhms = impedanceOhms
        self.impedanceMetadata = impedanceMetadata
        self.scale = scale
        self.profile = profile
    }

    public var isValid: Bool {
        weightKg.isFinite && weightKg > 0 && weightKg <= 262.143
            && (impedanceOhms.map { $0.isFinite && $0 > 0 && $0 <= 65535 } ?? true)
    }
}

/// Manufacturer identity rather than a platform-specific CoreBluetooth UUID.
public struct ScaleIdentifier: Codable, Equatable, Hashable, Sendable {
    public let companyID: UInt16
    public let macAddress: String

    public init?(companyID: UInt16, macAddress: String) {
        let components = macAddress.split(separator: ":", omittingEmptySubsequences: false)
        let bytes = components.compactMap { UInt8($0, radix: 16) }
        guard components.count == 6, components.allSatisfy({ $0.count == 2 }),
              bytes.count == 6 else { return nil }
        self.companyID = companyID
        self.macAddress = bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    public init?(manufacturerData: Data) {
        let bytes = Array(manufacturerData)
        guard bytes.count >= 14 else { return nil }
        companyID = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        macAddress = bytes[2..<8].reversed().map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    public func matches(_ data: Data) -> Bool { Self(manufacturerData: data) == self }
}
