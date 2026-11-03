import Foundation
import Testing
@testable import Practice

@Suite("Body Stats presentation")
@MainActor
struct BodyStatsPresentationTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func point(_ day: Int, _ value: Double, seconds: Double = 0) -> BodyTrendPoint {
        let date = Date(timeIntervalSince1970: Double(day) * 86_400 + seconds)
        return .init(id: "\(day)-\(seconds)-\(value)", date: date, value: value)
    }

    @Test func healthCopiesAreRemovedButDistinctReadingsRemain() {
        let scale = [point(1, 67.8)]
        let health = [point(1, 67.8, seconds: 0.1), point(1, 68.2, seconds: 30), point(2, 67.8)]
        let result = BodyTrend.mergingWeight(scale: scale, health: health)
        #expect(result.count == 3)
        #expect(result.first?.id == scale.first?.id)
        #expect(result.last?.date == point(2, 67.8).date)
    }

    @Test func smoothingUsesCalendarDaysAndDoesNotCarryAcrossGaps() {
        let values = [point(0, 60), point(0, 80, seconds: 100), point(6, 80), point(14, 90)]
        let result = BodyTrend.sevenDayMeans(values, calendar: calendar)
        #expect(result.map(\.value) == [70, 75, 90])
    }

    @Test func sparseAndEmptySeriesDoNotInventChanges() {
        #expect(BodyTrend.sevenDayMeans([], calendar: calendar).isEmpty)
        #expect(BodyTrend.change([], metric: .weight) == nil)
        #expect(BodyTrend.change([point(0, 70)], metric: .bodyFat) == nil)
        #expect(BodyTrend.change([point(0, 70), point(1, 69)], metric: .weight) == nil)
    }

    @Test func sustainedChangeComparesObservedWeeks() throws {
        let values = [point(0, 72), point(1, 70), point(35, 68), point(36, 66)]
        let change = try #require(BodyTrend.change(values, metric: .weight))
        #expect(change.contains("first to latest week"))
        #expect(change.contains("4"))
        #expect(BodyTrend.change([point(0, 72), point(35, 68)], metric: .weight)?.contains("first to latest day") == true)
    }

    @Test func rangeFiltersAgainstTodayRatherThanPretendingOldDataIsRecent() {
        let now = point(400, 0).date
        let points = [point(0, 70), point(390, 69), point(401, 68)]
        #expect(BodyTrendRange.month.filter(points, now: now).map(\.value) == [69])
        #expect(BodyTrendRange.all.filter(points, now: now).count == 3)
    }

    @Test func roundedBodyFatChangesDoNotImplySubPercentPrecision() throws {
        let tiny = try #require(BodyTrend.change([point(0, 19.2), point(35, 19.1)], metric: .bodyFat))
        #expect(tiny.contains("No change at displayed precision"))
        let onePoint = try #require(BodyTrend.change([point(0, 20), point(35, 19)], metric: .bodyFat))
        #expect(onePoint.contains("percentage point ·"))
        #expect(!onePoint.contains("percentage points"))
    }

    @Test func latestWeightOnlyReadingDoesNotEraseOrRedateEarlierEstimate() throws {
        let scale = try #require(ScaleIdentifier(companyID: 0xA0AC, macAddress: "A0:91:5B:35:E2:A8"))
        let first = try BodyMeasurementRecord(.init(date: point(1, 0).date, weightKg: 67.8,
            impedanceOhms: 529, scale: scale, profile: .init(heightCm: 172, age: 47, calculationSex: .male)))
        let second = try BodyMeasurementRecord(.init(date: point(2, 0).date, weightKg: 68, scale: scale))
        let snapshot = BodyStatsSnapshot(measurements: [second, first], waists: [],
            healthWeight: [], vo2: [], currentProfile: .init())
        #expect(snapshot.series[.weight]?.last?.recordID == second.id)
        #expect(snapshot.series[.bodyFat]?.last?.date == first.date)
        #expect(snapshot.series[.bodyFat]?.count == 1)
        #expect(snapshot.references[.bodyFat] != nil)
    }

    @Test func latestUnsupportedAgeClearsOlderReferenceBand() throws {
        let scale = try #require(ScaleIdentifier(companyID: 0xA0AC, macAddress: "A0:91:5B:35:E2:A8"))
        let records = try [79, 80].enumerated().map { index, age in
            try BodyMeasurementRecord(.init(date: point(index, 0).date, weightKg: 67.8, impedanceOhms: 529,
                scale: scale, profile: .init(heightCm: 172, age: age, calculationSex: .male)))
        }
        let snapshot = BodyStatsSnapshot(measurements: records, waists: [],
            healthWeight: [], vo2: [], currentProfile: .init())
        #expect(snapshot.series[.bodyFat]?.count == 2)
        #expect(snapshot.references[.bodyFat] == nil)
    }

    @Test func manualWaistWorksWithoutScaleOrInventedBMIClassification() throws {
        let waist = try WaistMeasurementRecord(date: point(1, 0).date, circumferenceCm: 85, heightCm: 172)
        let snapshot = BodyStatsSnapshot(measurements: [], waists: [waist], healthWeight: [],
            vo2: [], currentProfile: .init(age: 47))
        #expect(snapshot.series[.waist]?.last?.value == 85)
        #expect(snapshot.waistRatio == 85.0 / 172.0)
        #expect(snapshot.waistRange == nil)
    }
}
