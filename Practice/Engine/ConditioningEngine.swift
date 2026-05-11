//
//  ConditioningEngine.swift
//  Practice
//
//  Created by Steve Bryce on 10/05/2026.
//

import HealthKit
import SwiftData

// MARK: - Conditioning Engine

/// Computes a trend-based conditioning score from HealthKit history.
/// Unlike the readiness score (daily, point-in-time), this is weekly
/// and measures the *direction and rate* of fitness change over 8 weeks.
public actor ConditioningEngine {

    private let store = HKHealthStore()

    public init() {}

    // MARK: - Main entry point

    func computeScore(
        workoutRecords: [WorkoutRecord],
        kbRecords: [KettlebellWeightRecord],
        bodyMassKg: Double?,
        consistencyPercent: Double
    ) async throws -> ConditioningResult {

        // Fetch all trend data in parallel
        async let hrRecovery  = fetchHRRecoveryRate()
        async let rhrSlope    = fetchSlope(.restingHeartRate,
                                           unit: .count().unitDivided(by: .minute()), days: 56)
        async let hrvSlope    = fetchSlope(.heartRateVariabilitySDNN,
                                           unit: HKUnit.secondUnit(with: .milli), days: 56)
        async let vo2Slope    = fetchVO2Slope(days: 90)

        let (hrr, rhr, hrv, vo2) = await (hrRecovery, rhrSlope, hrvSlope, vo2Slope)

        // KB strength-to-weight ratio
        let kbRatio: Double?
        if let mass = bodyMassKg, mass > 0,
           let swingPB = kbRecords.filter({ $0.exerciseType == .swing })
                                  .map(\.weightKg).max() {
            kbRatio = swingPB / mass
        } else {
            kbRatio = nil
        }

        return score(
            hrRecoveryRate:   hrr,
            rhrSlope:         rhr,
            hrvSlope:         hrv,
            vo2Slope:         vo2,
            consistencyPct:   consistencyPercent,
            kbRatio:          kbRatio
        )
    }

    // MARK: - Scoring

    private func score(
        hrRecoveryRate: Double?,
        rhrSlope: Double?,
        hrvSlope: Double?,
        vo2Slope: Double?,
        consistencyPct: Double,
        kbRatio: Double?
    ) -> ConditioningResult {

        var components: [(score: Double, weight: Double, label: String)] = []

        // HR Recovery Rate (25%)
        // Good: >20 bpm drop in 60s. Elite: >30. Poor: <12.
        var hrRecoveryScore: Double? = nil
        if let hrr = hrRecoveryRate {
            let s = clamp(normalize(hrr, low: 8, mid: 18, high: 30), 0, 100)
            hrRecoveryScore = s
            components.append((s, 0.25, "HR Recovery"))
        }

        // RHR Trend (20%)
        // Negative slope = HR going down = fitness improving.
        // Score 100 if falling >0.1 bpm/day, 50 if flat, 0 if rising >0.1 bpm/day.
        var rhrTrendScore: Double? = nil
        if let slope = rhrSlope {
            // Invert: negative slope is good
            let s = clamp(50 - (slope * 500), 0, 100)
            rhrTrendScore = s
            components.append((s, 0.20, "Resting HR Trend"))
        }

        // HRV Trend (20%)
        // Positive slope = HRV rising = fitness improving.
        var hrvTrendScore: Double? = nil
        if let slope = hrvSlope {
            let s = clamp(50 + (slope * 2000), 0, 100)
            hrvTrendScore = s
            components.append((s, 0.20, "HRV Trend"))
        }

        // VO2Max Trend (15%)
        var vo2TrendScore: Double? = nil
        if let slope = vo2Slope {
            let s = clamp(50 + (slope * 5000), 0, 100)
            vo2TrendScore = s
            components.append((s, 0.15, "VO₂ Max Trend"))
        }

        // Training Consistency (12%)
        let consistencyScore = consistencyPct
        components.append((consistencyScore, 0.12, "Consistency"))

        // Strength-to-Weight Ratio (8%)
        // Swing PB / bodyweight. S&S Simple target: 0.5 (32kg / ~64kg typical).
        // Score 100 at ratio ≥ 0.5, scales down from there.
        var kbScore: Double? = nil
        if let ratio = kbRatio {
            let s = clamp(normalize(ratio, low: 0.15, mid: 0.30, high: 0.50), 0, 100)
            kbScore = s
            components.append((s, 0.08, "Strength Ratio"))
        }

        let totalWeight = components.map(\.weight).reduce(0, +)
        let overall     = totalWeight == 0 ? 50.0 :
            components.map { $0.score * ($0.weight / totalWeight) }.reduce(0, +)

        return ConditioningResult(
            overallScore:       overall.rounded(),
            hrRecoveryScore:    hrRecoveryScore,
            rhrTrendScore:      rhrTrendScore,
            hrvTrendScore:      hrvTrendScore,
            vo2TrendScore:      vo2TrendScore,
            consistencyScore:   consistencyScore,
            strengthRatioScore: kbScore,
            hrRecoveryRate:     hrRecoveryRate,
            rhrSlope:           rhrSlope,
            hrvSlope:           hrvSlope,
            vo2Slope:           vo2Slope,
            kbRatio:            kbRatio
        )
    }

    // MARK: - HealthKit fetches

    /// HR recovery: average drop from peak HR to HR 60s after workout end,
    /// computed from the last 8 workout HR samples.
    private func fetchHRRecoveryRate() async -> Double? {
        let workoutType = HKObjectType.workoutType()
        let start = Calendar.current.date(byAdding: .day, value: -56, to: Date())!
        let pred  = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort  = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Fetch recent workouts
        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: workoutType, predicate: pred,
                                  limit: 10, sortDescriptors: [sort]) { _, s, _ in
                cont.resume(returning: (s as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }

        guard !workouts.isEmpty else { return nil }

        var recoveryRates: [Double] = []

        for workout in workouts {
            let hrUnit  = HKUnit.count().unitDivided(by: .minute())
            let hrType  = HKQuantityType(.heartRate)
            let wPred   = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate.addingTimeInterval(120)  // 2 min after end
            )

            let samples: [HKQuantitySample] = await withCheckedContinuation { cont in
                let q = HKSampleQuery(sampleType: hrType, predicate: wPred,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, _ in
                    cont.resume(returning: (s as? [HKQuantitySample]) ?? [])
                }
                store.execute(q)
            }

            guard samples.count >= 2 else { continue }

            let peakHR = samples
                .filter { $0.startDate <= workout.endDate }
                .map    { $0.quantity.doubleValue(for: hrUnit) }
                .max() ?? 0

            // HR 60s after workout ended
            let recoveryWindow = workout.endDate.addingTimeInterval(60)
            let afterSamples = samples.filter {
                $0.startDate > workout.endDate && $0.startDate <= recoveryWindow
            }
            guard let recoveryHR = afterSamples
                .map({ $0.quantity.doubleValue(for: hrUnit) })
                .min() else { continue }  // lowest HR in window = most recovered

            let drop = peakHR - recoveryHR
            if drop > 0 { recoveryRates.append(drop) }
        }

        guard !recoveryRates.isEmpty else { return nil }
        return recoveryRates.reduce(0, +) / Double(recoveryRates.count)
    }

    /// Linear regression slope (units/day) for a quantity type over the given window.
    /// Positive = metric rising over time.
    private func fetchSlope(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async -> Double? {
        let type  = HKQuantityType(identifier)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let pred  = HKQuery.predicateForSamples(withStart: start, end: Date())

        let samples: [(t: Double, v: Double)] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, _ in
                let pairs = (s as? [HKQuantitySample] ?? []).map { sample -> (t: Double, v: Double) in
                    let t = sample.startDate.timeIntervalSinceReferenceDate / 86400  // days
                    let v = sample.quantity.doubleValue(for: unit)
                    return (t, v)
                }
                cont.resume(returning: pairs)
            }
            store.execute(q)
        }

        return linearRegressionSlope(samples)
    }

    private func fetchVO2Slope(days: Int) async -> Double? {
        let unit  = HKUnit.literUnit(with: .milli)
                         .unitDivided(by: HKUnit.gramUnit(with: .kilo)
                         .unitMultiplied(by: .minute()))
        return await fetchSlope(.vo2Max, unit: unit, days: days)
    }

    // MARK: - Math

    /// Ordinary least-squares slope: Σ((t-t̄)(v-v̄)) / Σ((t-t̄)²)
    /// Returns nil if fewer than 3 points (slope would be meaningless).
    private func linearRegressionSlope(_ points: [(t: Double, v: Double)]) -> Double? {
        guard points.count >= 3 else { return nil }
        let n  = Double(points.count)
        let tBar = points.map(\.t).reduce(0, +) / n
        let vBar = points.map(\.v).reduce(0, +) / n
        let num  = points.map { ($0.t - tBar) * ($0.v - vBar) }.reduce(0, +)
        let den  = points.map { pow($0.t - tBar, 2) }.reduce(0, +)
        guard den > 0 else { return nil }
        return num / den
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        Swift.max(lo, Swift.min(hi, v))
    }

    private func normalize(_ v: Double, low: Double, mid: Double, high: Double) -> Double {
        if v <= low  { return 0 }
        if v >= high { return 100 }
        if v <= mid  { return ((v - low) / (mid - low)) * 50 }
        return 50 + ((v - mid) / (high - mid)) * 50
    }
}

// MARK: - ConditioningResult

public struct ConditioningResult: Sendable {
    public var overallScore: Double
    public var hrRecoveryScore: Double?
    public var rhrTrendScore: Double?
    public var hrvTrendScore: Double?
    public var vo2TrendScore: Double?
    public var consistencyScore: Double
    public var strengthRatioScore: Double?
    public var hrRecoveryRate: Double?      // raw bpm drop
    public var rhrSlope: Double?            // bpm/day
    public var hrvSlope: Double?            // ms/day
    public var vo2Slope: Double?            // ml/kg/min per day
    public var kbRatio: Double?             // swing PB / bodyweight

    public var label: String {
        switch overallScore {
        case 75...:   return "Strong Trend"
        case 55..<75: return "Improving"
        case 45..<55: return "Steady"
        case 25..<45: return "Declining"
        default:      return "Needs Focus"
        }
    }

    public var emoji: String {
        switch overallScore {
        case 70...:   return "📈"
        case 50..<70: return "➡️"
        default:      return "📉"
        }
    }

    public init(
        overallScore: Double, hrRecoveryScore: Double? = nil,
        rhrTrendScore: Double? = nil, hrvTrendScore: Double? = nil,
        vo2TrendScore: Double? = nil, consistencyScore: Double = 50,
        strengthRatioScore: Double? = nil, hrRecoveryRate: Double? = nil,
        rhrSlope: Double? = nil, hrvSlope: Double? = nil,
        vo2Slope: Double? = nil, kbRatio: Double? = nil
    ) {
        self.overallScore       = overallScore
        self.hrRecoveryScore    = hrRecoveryScore
        self.rhrTrendScore      = rhrTrendScore
        self.hrvTrendScore      = hrvTrendScore
        self.vo2TrendScore      = vo2TrendScore
        self.consistencyScore   = consistencyScore
        self.strengthRatioScore = strengthRatioScore
        self.hrRecoveryRate     = hrRecoveryRate
        self.rhrSlope           = rhrSlope
        self.hrvSlope           = hrvSlope
        self.vo2Slope           = vo2Slope
        self.kbRatio            = kbRatio
    }
}
