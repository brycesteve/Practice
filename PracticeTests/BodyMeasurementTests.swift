import Foundation
import Testing
@testable import Practice

@Suite("Scale protocol and measurement sessions")
struct ScaleProtocolTests {
    // Representative manufacturer packets built from the verified ScaleExperiment wire layout.
    // The reference directory contains decoder source, not an archived physical packet log.
    private let live = Data([0xAC,0xA0,0xA8,0xE2,0x35,0x5B,0x91,0xA0,0xA0,0xA1,0xA8,0x78,0x0D,0xAE])
    private let final = Data([0xAC,0xA0,0xA8,0xE2,0x35,0x5B,0x91,0xA0,0x20,0xA1,0xA8,0x78,0x0D,0xAE])
    private let impedance = Data([0xAC,0xA0,0xA8,0xE2,0x35,0x5B,0x91,0xA0,0xA2,0xB1,0xB2,0x94,0x06,0xBF])
    private let start = Date(timeIntervalSince1970: 1_000)

    private func scale() throws -> ScaleIdentifier {
        try #require(ScaleIdentifier(companyID: 0xA0AC, macAddress: "A0:91:5B:35:E2:A8"))
    }

    @Test func verifiedWeightBitLayout() {
        #expect(ScaleDecoder.decode(live) == .weight(kg: 67.8, isFinal: false))
        #expect(ScaleDecoder.decode(final) == .weight(kg: 67.8, isFinal: true))
    }

    @Test func impedanceAndUnknownMetadata() {
        #expect(ScaleDecoder.decode(impedance) == .impedance(ohms: 529, metadata: 0x1234))
    }

    @Test func checksumRejectsCorruption() {
        var corrupt = impedance
        corrupt[9] ^= 1
        #expect(ScaleDecoder.decode(corrupt) == nil)
        var upperChecksumBits = impedance
        upperChecksumBits[13] ^= 0xE0
        #expect(ScaleDecoder.decode(upperChecksumBits) == ScaleDecoder.decode(impedance))
    }

    @Test func truncationIsRejected() {
        for length in 0..<14 {
            #expect(ScaleDecoder.decode(Data(final.prefix(length))) == nil)
        }
    }

    @Test func companyHighByteDeterminesXOR() {
        var differentKey = final
        differentKey[1] = 0x42
        for index in 8..<14 { differentKey[index] ^= 0xA0 ^ 0x42 }
        #expect(ScaleDecoder.decode(differentKey) == .weight(kg: 67.8, isFinal: true))
    }

    @Test func identityUsesReversedMACAndCompany() throws {
        let selected = try scale()
        #expect(ScaleIdentifier(manufacturerData: final) == selected)
        var otherDevice = final
        otherDevice[2] ^= 1
        #expect(!selected.matches(otherDevice))
        #expect(ScaleIdentifier(companyID: 1, macAddress: "bad") == nil)
    }

    @Test func unknownFrameIsPreserved() {
        let payload: [UInt8] = [1,2,3,4,0x77]
        let sum = UInt8(payload.reduce(0) { $0 + Int($1) } & 31)
        let bytes = Data(Array(final.prefix(8)) + (payload + [sum]).map { $0 ^ 0xA0 })
        #expect(ScaleDecoder.decode(bytes) == .unknown(type: 0x77, rawValue: 0x01020304, bytes: payload + [sum]))
    }

    @Test func finalWeightWaitsForImpedanceAndCompletesOnce() throws {
        var session = ScaleMeasurementSession(startedAt: start, scale: try scale())
        session.receive(try #require(ScaleDecoder.decode(live)), at: start)
        session.receive(try #require(ScaleDecoder.decode(final)), at: start.addingTimeInterval(1))
        #expect(session.completedMeasurement == nil)
        session.receive(try #require(ScaleDecoder.decode(impedance)), at: start.addingTimeInterval(5))
        let completed = try #require(session.completedMeasurement)
        for _ in 0..<20 {
            session.receive(.impedance(ohms: 532, metadata: 999), at: start.addingTimeInterval(6))
            session.receive(.weight(kg: 70, isFinal: true), at: start.addingTimeInterval(6))
        }
        #expect(session.completedMeasurement == completed)
        #expect(completed.weightKg == 67.8)
        #expect(completed.impedanceMetadata == 0x1234)
        #expect(completed.date == start.addingTimeInterval(1))
    }

    @Test func impedanceBeforeFinalIsSupported() throws {
        var session = ScaleMeasurementSession(startedAt: start, scale: try scale())
        session.receive(.impedance(ohms: 529, metadata: 1), at: start)
        session.receive(.weight(kg: 67.8, isFinal: true), at: start.addingTimeInterval(1))
        #expect(session.completedMeasurement?.impedanceOhms == 529)
    }

    @Test func duplicatesDoNotExtendWeightOnlyDeadline() throws {
        var session = ScaleMeasurementSession(startedAt: start, scale: try scale())
        session.receive(.weight(kg: 67.8, isFinal: true), at: start)
        session.receive(.weight(kg: 68, isFinal: true), at: start.addingTimeInterval(11))
        session.advance(to: start.addingTimeInterval(11.9))
        #expect(session.completedMeasurement == nil)
        session.advance(to: start.addingTimeInterval(12))
        #expect(session.completedMeasurement?.weightKg == 67.8)
        #expect(session.completedMeasurement?.impedanceOhms == nil)
        session.receive(.impedance(ohms: 529, metadata: 0), at: start.addingTimeInterval(13))
        #expect(session.completedMeasurement?.impedanceOhms == nil)
    }

    @Test func noFinalWeightTimesOutWithoutRecordingLiveWeight() throws {
        var session = ScaleMeasurementSession(startedAt: start, scale: try scale())
        session.receive(.weight(kg: 67, isFinal: false), at: start)
        session.advance(to: start.addingTimeInterval(60))
        #expect(session.failure != nil)
        #expect(session.completedMeasurement == nil)
    }

    @Test func invalidValuesAndCancellationCannotComplete() throws {
        var session = ScaleMeasurementSession(startedAt: start, scale: try scale())
        session.receive(.weight(kg: .nan, isFinal: true), at: start)
        session.receive(.weight(kg: 0, isFinal: true), at: start)
        session.receive(.impedance(ohms: 0, metadata: 0), at: start)
        #expect(session.finalWeightKg == nil)
        #expect(session.impedanceOhms == nil)
        session.cancel()
        session.receive(.weight(kg: 67.8, isFinal: true), at: start)
        session.advance(to: start.addingTimeInterval(100))
        #expect(session.completedMeasurement == nil)
    }

    @Test func attemptsHaveDistinctStableIDs() throws {
        let first = ScaleMeasurementSession(startedAt: start, scale: try scale())
        let second = ScaleMeasurementSession(startedAt: start, scale: try scale())
        #expect(first.id != second.id)
    }
}

@Suite("Body composition and references")
struct BodyCompositionTests {
    let calculator = KushnerSchoellerCalculator()

    @Test func maleRegressionFixture() throws {
        let profile = BodyProfileSnapshot(heightCm: 172, age: 47, calculationSex: .male, waistCm: 85)
        let result = calculator.calculate(weightKg: 67.8, impedanceOhms: 529, profile: profile)
        #expect(abs(try #require(result.totalBodyWaterLitres).value - 40.24045671077505) < 1e-9)
        #expect(abs(try #require(result.fatFreeMassKg).value - 54.973301517452256) < 1e-9)
        #expect(abs(try #require(result.fatMassKg).value - 12.82669848254774) < 1e-9)
        #expect(abs(try #require(result.bodyFatPercentage).value - 18.918434340040914) < 1e-9)
        #expect(abs(try #require(result.skeletalMuscleKg).value - 28.015678638941402) < 1e-9)
        #expect(abs(try #require(result.basalMetabolicRate).value - 1557.4233127769687) < 1e-9)
        #expect(abs(try #require(result.bmi).value - 22.917793401838832) < 1e-9)
        #expect(abs(try #require(result.waistToHeightRatio).value - 85.0 / 172) < 1e-12)
        #expect(result.bodyFatPercentage?.algorithmVersion == 1)
        #expect(result.bodyFatPercentage?.method == KushnerSchoellerCalculator.method)
    }

    @Test func femaleRegressionFixture() throws {
        let result = calculator.calculate(weightKg: 50.6, impedanceOhms: 532,
            profile: .init(heightCm: 154.94, age: 35, calculationSex: .female))
        #expect(abs(try #require(result.totalBodyWaterLitres).value - 30.86568078045113) < 1e-9)
        #expect(abs(try #require(result.fatFreeMassKg).value - 42.16623057438679) < 1e-9)
        #expect(abs(try #require(result.bodyFatPercentage).value - 16.667528509117023) < 1e-9)
        #expect(abs(try #require(result.skeletalMuscleKg).value - 20.712052337593985) < 1e-9)
        #expect(abs(try #require(result.basalMetabolicRate).value - 1280.7905804067545) < 1e-9)
    }

    @Test func freshWeightChangesCalculation() {
        let profile = BodyProfileSnapshot(heightCm: 172, age: 47, calculationSex: .male)
        let first = calculator.calculate(weightKg: 67.8, impedanceOhms: 529, profile: profile)
        let second = calculator.calculate(weightKg: 72, impedanceOhms: 529, profile: profile)
        #expect(first.bodyFatPercentage != second.bodyFatPercentage)
        #expect(first.totalBodyWaterLitres != second.totalBodyWaterLitres)
    }

    @Test func weightOnlyStillProducesBMIAndWaistRatio() {
        let result = calculator.calculate(weightKg: 80, impedanceOhms: nil,
            profile: .init(heightCm: 200, waistCm: 100))
        #expect(result.bmi?.value == 20)
        #expect(result.waistToHeightRatio?.value == 0.5)
        #expect(result.bodyFatPercentage == nil)
        #expect(result.basalMetabolicRate == nil)
    }

    @Test func missingModelOrAgeDoesNotGuess() {
        #expect(calculator.calculate(weightKg: 67.8, impedanceOhms: 529,
            profile: .init(heightCm: 172, age: 47)).bodyFatPercentage == nil)
        #expect(calculator.calculate(weightKg: 67.8, impedanceOhms: 529,
            profile: .init(heightCm: 172, calculationSex: .male)).bodyFatPercentage == nil)
        #expect(calculator.calculate(weightKg: 67.8, impedanceOhms: 529,
            profile: .init(heightCm: 172, age: 17, calculationSex: .male)).bodyFatPercentage == nil)
    }

    @Test func impossibleResultsAreNotClamped() {
        let profile = BodyProfileSnapshot(heightCm: 172, age: 47, calculationSex: .male)
        #expect(calculator.calculate(weightKg: 30, impedanceOhms: 50, profile: profile).bodyFatPercentage == nil)
        #expect(calculator.calculate(weightKg: .nan, impedanceOhms: 529, profile: profile).bmi == nil)
        #expect(calculator.calculate(weightKg: 67.8, impedanceOhms: 0, profile: profile).bodyFatPercentage == nil)
        #expect(calculator.calculate(weightKg: 67.8, impedanceOhms: 529,
            profile: .init(heightCm: 0)).bmi == nil)
    }

    @Test func bmiBoundaries() {
        #expect(BodyReferences.bmi.classify(18.499) == .low)
        #expect(BodyReferences.bmi.classify(18.5) == .reference)
        #expect(BodyReferences.bmi.classify(24.999) == .reference)
        #expect(BodyReferences.bmi.classify(25) == .elevated)
        #expect(BodyReferences.bmi.classify(30) == .high)
        #expect(BodyReferences.bmi.classify(.nan) == nil)
    }

    @Test func waistBoundaries() {
        #expect(BodyReferences.waistToHeight.classify(0.399) == .low)
        #expect(BodyReferences.waistToHeight.classify(0.4) == .reference)
        #expect(BodyReferences.waistToHeight.classify(0.5) == .elevated)
        #expect(BodyReferences.waistToHeight.classify(0.6) == .high)
    }

    @Test func originalGallagherTable4() throws {
        let male = try #require(BodyReferences.bodyFat(age: 47, sex: .male))
        #expect(male.lower == 11 && male.upper == 22 && male.high == 28)
        let female = try #require(BodyReferences.bodyFat(age: 35, sex: .female))
        #expect(female.lower == 21 && female.upper == 33 && female.high == 39)
        for band in BodyReferences.bodyFatBands {
            #expect(band.range.classify(band.range.lower - 0.01) == .low)
            #expect(band.range.classify(band.range.lower) == .reference)
            #expect(band.range.classify(band.range.upper) == .elevated)
            #expect(band.range.classify(band.range.high) == .high)
        }
        #expect(BodyReferences.bodyFat(age: 19, sex: .male) == nil)
        #expect(BodyReferences.bodyFat(age: 80, sex: .female) == nil)
        #expect(BodyReferences.bodyFat(age: 35, sex: nil) == nil)
    }

    @Test func ageUsesBirthdayNotJustYear() throws {
        var configuration = BodyConfiguration()
        configuration.dateOfBirth = try #require(Calendar.current.date(from: DateComponents(year: 1979, month: 10, day: 15)))
        let before = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 14)))
        let after = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15)))
        #expect(configuration.fallbackProfile(at: before).age == 46)
        #expect(configuration.fallbackProfile(at: after).age == 47)
        #expect(BodyConfiguration().fallbackProfile(at: before).calculationSex == nil)
    }
}

@Suite("Body measurement delivery")
@MainActor
struct BodyMeasurementDeliveryTests {
    @Test func outboxSurvivesRelaunchAndDeduplicatesUntilAcknowledged() throws {
        let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let scale = try #require(ScaleIdentifier(companyID: 0xA0AC, macAddress: "A0:91:5B:35:E2:A8"))
        let raw = RawBodyMeasurement(weightKg: 67.8, impedanceOhms: 529, impedanceMetadata: 0x1234, scale: scale)
        let first = BodyMeasurementOutbox(fileURL: url)
        try first.enqueue(raw)
        try first.enqueue(raw)
        #expect(first.pending.count == 1)
        let relaunched = BodyMeasurementOutbox(fileURL: url)
        #expect(relaunched.pending == [raw])
        try relaunched.acknowledge(UUID()) // Unknown ack cannot remove a real reading.
        #expect(relaunched.pending.count == 1)
        try relaunched.acknowledge(raw.id)
        #expect(BodyMeasurementOutbox(fileURL: url).pending.isEmpty)
    }

    @Test func corruptOutboxIsNeverOverwritten() throws {
        let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("invalid".utf8)
        try bytes.write(to: url)
        let outbox = BodyMeasurementOutbox(fileURL: url)
        #expect(outbox.errorMessage != nil)
        let scale = try #require(ScaleIdentifier(companyID: 1, macAddress: "00:00:00:00:00:01"))
        #expect(throws: (any Error).self) {
            try outbox.enqueue(RawBodyMeasurement(weightKg: 70, scale: scale))
        }
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func olderSyncPayloadStillDecodes() throws {
        let old = try JSONDecoder().decode(WCSyncPayload.self, from: Data("{}".utf8))
        #expect(old.bodyConfiguration == nil)
        var configuration = BodyConfiguration()
        configuration.heightCm = 172
        configuration.calculationSex = .male
        let payload = WCSyncPayload(bodyConfiguration: configuration)
        let roundTrip = try JSONDecoder().decode(WCSyncPayload.self, from: JSONEncoder().encode(payload))
        #expect(roundTrip.bodyConfiguration == configuration)
    }
}
