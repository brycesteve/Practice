import Foundation

enum ScaleFrame: Equatable, Sendable {
    case weight(kg: Double, isFinal: Bool)
    case impedance(ohms: Double, metadata: UInt16)
    case unknown(type: UInt8, rawValue: UInt32, bytes: [UInt8])
}

/// Adapted from CodexReference/ScaleExperiment without changing its verified wire decoding.
enum ScaleDecoder {
    static func decode(_ manufacturerData: Data) -> ScaleFrame? {
        let data = Array(manufacturerData)
        guard data.count >= 14 else { return nil }
        let companyID = UInt16(data[0]) | (UInt16(data[1]) << 8)
        let xorKey = UInt8(companyID >> 8)
        let payload = data.suffix(6).map { $0 ^ xorKey }
        let checksum = payload.prefix(5).reduce(0) { $0 + UInt16($1) } & 0x1F
        guard checksum == UInt16(payload[5] & 0x1F) else { return nil }
        let rawValue = (UInt32(payload[0]) << 24) | (UInt32(payload[1]) << 16)
            | (UInt32(payload[2]) << 8) | UInt32(payload[3])
        switch payload[4] {
        case 0xAD:
            return .weight(kg: Double(rawValue & 0x3FFFF) / 1000,
                           isFinal: (rawValue & 0x8000_0000) != 0)
        case 0xA6:
            // Experimentally inferred whole ohms. Bytes 2–3 remain uninterpreted.
            return .impedance(ohms: Double((UInt16(payload[0]) << 8) | UInt16(payload[1])),
                              metadata: (UInt16(payload[2]) << 8) | UInt16(payload[3]))
        default:
            return .unknown(type: payload[4], rawValue: rawValue, bytes: payload)
        }
    }
}

/// Clock-driven state makes repeated frames, expiry and cancellation deterministic in tests.
/// The first stable weight freezes the weight and starts a non-extending impedance deadline.
struct ScaleMeasurementSession: Sendable {
    let id = UUID()
    let startedAt: Date
    let scale: ScaleIdentifier
    var impedanceWait: TimeInterval = 12
    var searchTimeout: TimeInterval = 60
    private(set) var liveWeightKg: Double?
    private(set) var finalWeightKg: Double?
    private(set) var impedanceOhms: Double?
    private(set) var impedanceMetadata: UInt16?
    private(set) var finalDate: Date?
    private(set) var completedMeasurement: RawBodyMeasurement?
    private(set) var failure: String?
    private(set) var cancelled = false

    var isFinished: Bool { completedMeasurement != nil || failure != nil || cancelled }

    mutating func receive(_ frame: ScaleFrame, at date: Date) {
        guard !isFinished else { return }
        advance(to: date)
        guard !isFinished else { return }
        switch frame {
        case let .weight(kg, isFinal):
            guard kg.isFinite, kg > 0, kg <= 262.143 else { return }
            liveWeightKg = kg
            if isFinal && finalWeightKg == nil {
                finalWeightKg = kg
                finalDate = date
            }
        case let .impedance(ohms, metadata):
            guard ohms.isFinite, ohms > 0 else { return }
            impedanceOhms = ohms
            impedanceMetadata = metadata
        case .unknown: return
        }
        if finalWeightKg != nil && impedanceOhms != nil { complete() }
    }

    mutating func advance(to date: Date) {
        guard !isFinished else { return }
        if let finalDate {
            if date.timeIntervalSince(finalDate) >= impedanceWait { complete() }
        } else if date.timeIntervalSince(startedAt) >= searchTimeout {
            failure = "No stabilised weight received. Step off, then try again."
        }
    }

    mutating func cancel() { cancelled = true }

    private mutating func complete() {
        guard completedMeasurement == nil, let weight = finalWeightKg, let date = finalDate else { return }
        completedMeasurement = RawBodyMeasurement(id: id, date: date, weightKg: weight,
            impedanceOhms: impedanceOhms, impedanceMetadata: impedanceMetadata, scale: scale)
    }
}
