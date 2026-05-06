// RecoveryEngine.swift — TrainingShared
// Calculates a daily Readiness Score (0–100) from HealthKit metrics.
//
// Weighted formula:
//   HRV (morning)           30%  — most predictive of recovery
//   Resting Heart Rate      20%  — elevated = stress/fatigue
//   Sleep Duration          20%  — 7–9h optimal
//   Sleep Quality           15%  — deep + REM %
//   Respiratory Rate         5%  — elevated = illness/stress
//   Training Load (2-day)   10%  — recent active energy = fatigue signal

import Foundation
import HealthKit

public struct RecoveryMetrics: Sendable {
    public var hrv: Double?                    // ms (SDNN or RMSSD)
    public var restingHeartRate: Double?       // bpm
    public var sleepDuration: Double?          // hours last night
    public var sleepQualityPercent: Double?    // % time in deep+REM (0–100)
    public var respiratoryRate: Double?        // breaths/min
    public var activeEnergyYesterday: Double?  // kcal
    public var activeEnergyTwoDaysAgo: Double? // kcal
    
    public init(hrv: Double? = nil, restingHeartRate: Double? = nil,
                sleepDuration: Double? = nil, sleepQualityPercent: Double? = nil,
                respiratoryRate: Double? = nil, activeEnergyYesterday: Double? = nil,
                activeEnergyTwoDaysAgo: Double? = nil) {
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepDuration = sleepDuration
        self.sleepQualityPercent = sleepQualityPercent
        self.respiratoryRate = respiratoryRate
        self.activeEnergyYesterday = activeEnergyYesterday
        self.activeEnergyTwoDaysAgo = activeEnergyTwoDaysAgo
    }
}

public struct RecoveryScore: Sendable {
    public var overall: Double                 // 0–100
    public var hrvContribution: Double?
    public var restingHRContribution: Double?
    public var sleepDurationContribution: Double?
    public var sleepQualityContribution: Double?
    public var respiratoryContribution: Double?
    public var trainingLoadContribution: Double?
    public var metrics: RecoveryMetrics
    public var dataQuality: DataQuality
    
    public init(overall: Double, hrvContribution: Double? = nil,
                restingHRContribution: Double? = nil, sleepDurationContribution: Double? = nil,
                sleepQualityContribution: Double? = nil, respiratoryContribution: Double? = nil,
                trainingLoadContribution: Double? = nil, metrics: RecoveryMetrics,
                dataQuality: DataQuality) {
        self.overall = overall
        self.hrvContribution = hrvContribution
        self.restingHRContribution = restingHRContribution
        self.sleepDurationContribution = sleepDurationContribution
        self.sleepQualityContribution = sleepQualityContribution
        self.respiratoryContribution = respiratoryContribution
        self.trainingLoadContribution = trainingLoadContribution
        self.metrics = metrics
        self.dataQuality = dataQuality
    }
    
    public enum DataQuality: Sendable {
        case rich           // 4+ metrics available
        case moderate       // 2–3 metrics
        case limited        // 0–1 metrics (score less reliable)
    }
    
    public var label: String {
        switch overall {
        case 85...100: return "Excellent"
        case 70..<85:  return "Good"
        case 50..<70:  return "Moderate"
        case 30..<50:  return "Poor"
        default:       return "Very Low"
        }
    }
    
    public var emoji: String {
        switch overall {
        case 85...100: return "🟢"
        case 70..<85:  return "🔵"
        case 50..<70:  return "🟡"
        case 30..<50:  return "🟠"
        default:       return "🔴"
        }
    }
}

// MARK: - Engine

public actor RecoveryEngine {
    
    private let store = HKHealthStore()
    
    public init() {}
    
    // MARK: - Main entry point
    
    /// Fetch all relevant HealthKit metrics and compute today's readiness score.
    public func computeScore() async throws -> RecoveryScore {
        let metrics = try await fetchMetrics()
        return score(from: metrics)
    }
    
    // MARK: - Fetch metrics
    
    private func fetchMetrics() async throws -> RecoveryMetrics {
        async let hrv              = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
        async let rhr              = fetchLatestQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let sleep            = fetchLastNightSleep()
        async let respRate         = fetchLatestQuantity(.respiratoryRate, unit: .count().unitDivided(by: .minute()))
        async let energyYesterday  = fetchActiveEnergy(daysAgo: 1)
        async let energyTwoDaysAgo = fetchActiveEnergy(daysAgo: 2)
        
        let (hrvVal, rhrVal, sleepResult, respVal, e1, e2) = try await (hrv, rhr, sleep, respRate, energyYesterday, energyTwoDaysAgo)
        
        return RecoveryMetrics(
            hrv: hrvVal,
            restingHeartRate: rhrVal,
            sleepDuration: sleepResult.hours,
            sleepQualityPercent: sleepResult.qualityPercent,
            respiratoryRate: respVal,
            activeEnergyYesterday: e1,
            activeEnergyTwoDaysAgo: e2
        )
    }
    
    // MARK: - Score calculation
    
    private func score(from m: RecoveryMetrics) -> RecoveryScore {
        var components: [(score: Double, weight: Double)] = []
        
        // HRV (30%) — score using population norms: <20ms poor, 20–50ms average, >80ms excellent
        var hrvC: Double? = nil
        if let hrv = m.hrv {
            let s = clamp(normalize(hrv, low: 15, mid: 40, high: 80), 0, 100)
            hrvC = s
            components.append((s, 0.30))
        }
        
        // Resting HR (20%) — lower is better; <50 excellent, 50–70 normal, >85 poor
        var rhrC: Double? = nil
        if let rhr = m.restingHeartRate {
            let s = clamp(normalize(100 - rhr, low: 15, mid: 30, high: 50), 0, 100)
            rhrC = s
            components.append((s, 0.20))
        }
        
        // Sleep Duration (20%) — target 7.5–9h; <5h or >10h penalised
        var sleepDurC: Double? = nil
        if let hours = m.sleepDuration {
            let s: Double
            switch hours {
            case 0..<4:    s = 5
            case 4..<5.5:  s = 30
            case 5.5..<6.5:s = 55
            case 6.5..<7:  s = 72
            case 7..<9.5:  s = 100
            case 9.5..<11: s = 80
            default:       s = 60
            }
            sleepDurC = s
            components.append((s, 0.20))
        }
        
        // Sleep Quality (15%) — % time in deep + REM
        var sleepQC: Double? = nil
        if let quality = m.sleepQualityPercent {
            // 40%+ is excellent, <15% is poor
            let s = clamp(normalize(quality, low: 10, mid: 25, high: 40), 0, 100)
            sleepQC = s
            components.append((s, 0.15))
        }
        
        // Respiratory Rate (5%) — normal ~12–20; elevated = stress
        var respC: Double? = nil
        if let resp = m.respiratoryRate {
            let s: Double
            switch resp {
            case 0..<12:   s = 70   // low is unusual but not necessarily bad
            case 12..<16:  s = 100
            case 16..<18:  s = 85
            case 18..<20:  s = 65
            default:       s = 35   // elevated
            }
            respC = s
            components.append((s, 0.05))
        }
        
        // Training Load (10%) — recent heavy energy spend = less recovery capacity
        var loadC: Double? = nil
        let totalLoad = (m.activeEnergyYesterday ?? 0) + (m.activeEnergyTwoDaysAgo ?? 0) * 0.5
        if m.activeEnergyYesterday != nil || m.activeEnergyTwoDaysAgo != nil {
            // <300kcal combined = fully rested, >1200kcal = heavy load
            let s = clamp(100 - normalize(totalLoad, low: 200, mid: 700, high: 1200), 0, 100)
            loadC = s
            components.append((s, 0.10))
        }
        
        // Weighted average, re-normalised if some metrics missing
        let totalWeight = components.map(\.weight).reduce(0, +)
        let weighted: Double
        if totalWeight == 0 {
            weighted = 50   // no data: neutral score
        } else {
            weighted = components.map { $0.score * ($0.weight / totalWeight) }.reduce(0, +)
        }
        
        let quality: RecoveryScore.DataQuality
        switch components.count {
        case 4...: quality = .rich
        case 2...3: quality = .moderate
        default: quality = .limited
        }
        
        return RecoveryScore(
            overall: weighted.rounded(),
            hrvContribution: hrvC,
            restingHRContribution: rhrC,
            sleepDurationContribution: sleepDurC,
            sleepQualityContribution: sleepQC,
            respiratoryContribution: respC,
            trainingLoadContribution: loadC,
            metrics: m,
            dataQuality: quality
        )
    }
    
    // MARK: - HealthKit queries
    
    private func fetchLatestQuantity(_ type: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let quantityType = HKQuantityType(type)
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
    
    private struct SleepResult: Sendable {
        var hours: Double?
        var qualityPercent: Double?
    }
    
    private func fetchLastNightSleep() async throws -> SleepResult {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let now = Date()
        
        // Wider window to safely capture the full last sleep session
        let startDate = Calendar.current.date(byAdding: .hour, value: -36, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now)
        
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sleepSamples = (samples as? [HKCategorySample] ?? [])
                
                // MARK: - Helpers
                
                func isAsleep(_ sample: HKCategorySample) -> Bool {
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        return true
                    default:
                        return false
                    }
                }
                
                func mergeIntervals(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
                    let sorted = intervals.sorted { $0.0 < $1.0 }
                    var result: [(Date, Date)] = []
                    
                    for interval in sorted {
                        if let last = result.last, interval.0 <= last.1 {
                            result[result.count - 1].1 = max(last.1, interval.1)
                        } else {
                            result.append(interval)
                        }
                    }
                    
                    return result
                }
                
                // MARK: - Build most recent sleep session
                
                let asleepSamples = sleepSamples.filter(isAsleep)
                    .sorted { $0.startDate > $1.startDate }
                
                var session: [HKCategorySample] = []
                
                for sample in asleepSamples {
                    if session.isEmpty {
                        session.append(sample)
                        continue
                    }
                    
                    let last = session.last!
                    
                    // Allow small gaps (5 min) to keep session contiguous
                    if sample.endDate >= last.startDate.addingTimeInterval(-1800) {
                        session.append(sample)
                    } else {
                        break
                    }
                }
                
                guard !session.isEmpty else {
                    continuation.resume(returning: SleepResult(hours: nil, qualityPercent: nil))
                    return
                }
                
                // MARK: - Total sleep (deduplicated)
                
                let mergedSleep = mergeIntervals(
                    session.map { ($0.startDate, $0.endDate) }
                )
                
                let totalSleep = mergedSleep
                    .map { $0.1.timeIntervalSince($0.0) }
                    .reduce(0, +)
                
                // MARK: - Quality (Deep + REM only, also deduplicated)
                
                let qualitySamples = session.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                
                let mergedQuality = mergeIntervals(
                    qualitySamples.map { ($0.startDate, $0.endDate) }
                )
                
                let qualityTime = mergedQuality
                    .map { $0.1.timeIntervalSince($0.0) }
                    .reduce(0, +)
                
                // MARK: - Final values
                
                let hours = totalSleep > 0 ? totalSleep / 3600 : nil
                let qualityPercent = totalSleep > 0 ? (qualityTime / totalSleep) * 100 : nil
                
                continuation.resume(
                    returning: SleepResult(
                        hours: hours,
                        qualityPercent: qualityPercent
                    )
                )
            }
            
            store.execute(query)
        }
    }
    
    private func fetchActiveEnergy(daysAgo: Int) async throws -> Double? {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let cal = Calendar.current
        let startOfTargetDay = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
        let endOfTargetDay   = cal.date(byAdding: .day, value: 1, to: startOfTargetDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfTargetDay, end: endOfTargetDay)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                let kcal = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: kcal)
            }
            store.execute(query)
        }
    }
    
    // MARK: - Math helpers
    
    /// Linear interpolation: maps value from [low, high] range to [0, 100]
    private func normalize(_ value: Double, low: Double, mid: Double, high: Double) -> Double {
        if value <= low  { return 0 }
        if value >= high { return 100 }
        if value <= mid  { return ((value - low) / (mid - low)) * 50 }
        return 50 + ((value - mid) / (high - mid)) * 50
    }
    
    private func clamp(_ value: Double, _ min: Double, _ max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
