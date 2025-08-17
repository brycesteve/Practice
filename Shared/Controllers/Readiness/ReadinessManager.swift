import Foundation
import HealthKit
import Observation
import OSLog
import UserNotifications


@MainActor
@Observable
class ReadinessManager {
    var readinessScore: Int = 0
    var hrv: Double = 0
    var restingHR: Double = 0
    var sleepActual: TimeInterval = 0
    var sleepEffective: TimeInterval = 0
    var strain: Double = 0
    var sleepConsistency: Double? = nil
    var sleepAvg: TimeInterval = 0
    
    static let shared = ReadinessManager()
    private var observerQueries: [HKObserverQuery] = []
    private var observersStarted = false
    
    let healthStore = HKHealthStore()
    
    var avgHRV: Double = 0
    var avgRHR: Double = 0
    var avgStrain: Double = 0
    
    // EMA smoothing factor for adaptive baseline
    private let alpha = 0.2
    
    // UserDefaults key for sleep-based resting HR baseline
    private let baselineKey = "sleepRHRBaseline"
    
    func setupObserversIfNeeded() {
        guard !observersStarted else { return }
        observersStarted = true
        Task { @MainActor in
            await setupBackgroundObservers()
            await refresh()
        }
        
    }
    
    // MARK: - Background Delivery Setup
    private func setupBackgroundObservers() async {
        let quantityTypes: [HKQuantityTypeIdentifier: HKUpdateFrequency] = [
            .heartRateVariabilitySDNN: .immediate,
            .restingHeartRate: .hourly,
            .heartRate: .hourly,
            .activeEnergyBurned: .hourly
        ]
        
        let categoryTypes: [HKCategoryTypeIdentifier: HKUpdateFrequency] = [
            .sleepAnalysis: .immediate
        ]
        
        // Enable background delivery
        for (id, frequency) in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                do {
                    try await healthStore
                        .enableBackgroundDelivery(for: type, frequency: frequency)
                }
                catch(let error) {
                    Logger.default.error("Background Failure: \(error.localizedDescription)")
                }
                addObserver(for: type)
            }
        }
        
        for (id, frequency) in categoryTypes {
            if let type = HKCategoryType.categoryType(forIdentifier: id) {
                do {
                    try await healthStore.enableBackgroundDelivery(for: type, frequency: frequency)
                }
                catch (let error) {
                    Logger.default.error("Background Failure: \(error.localizedDescription)")
                }
                addObserver(for: type)
            }
        }
    }
    
    // MARK: - Observer Queries
    private func addObserver(for type: HKSampleType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) {
 [weak self] _,
 completionHandler,
 error in
            if let error = error {
                Logger.default.error("ObserverQuery error for \(type): \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            Logger.default.info("🔄 Background update triggered for \(type.identifier)")
            
//            let content = UNMutableNotificationContent()
//            content.title = "Data Refreshed"
//            content.body = "Refreshed now"
//            
//            let trigger = UNTimeIntervalNotificationTrigger(
//                timeInterval: 10,
//                repeats: false
//            )
//            
//            let request = UNNotificationRequest(
//                identifier: UUID().uuidString,
//                content: content,
//                trigger: trigger
//            )
//            
//            UNUserNotificationCenter.current().add(request)
            
            Task { @MainActor in
                await self?.refresh()
                completionHandler()
            }
        }
        
        healthStore.execute(query)
        observerQueries.append(query)
    }
    
    // Call this if you ever need to tear down observers
    func stopObservers() {
        for q in observerQueries {
            healthStore.stop(q)
        }
        observerQueries.removeAll()
    }
    
    func refresh() async {
        do {
            // Fetch today’s core metrics in parallel
            async let todayHRV = fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
            // Use sleep-based resting heart rate instead of simple average restingHR
            async let todayRHR = fetchSleepBasedRestingHeartRate()
            async let todaySleep = fetchSleepDuration()
            async let yesterdayStrain = fetchSumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: .yesterday, end: .yesterdayEnd)
            
            async let sleepAvg = fetch7DayAverageSleepHours()
            
            async let consistencyScore = try? sleepConsistencyScore()
            let consistency = await consistencyScore ?? 100
            self.sleepConsistency = consistency
            
            let (hrv, rhr, sleep, strain, avgSleep) = try await (
                todayHRV,
                todayRHR,
                todaySleep,
                yesterdayStrain,
                sleepAvg
            )
            self.hrv = hrv ?? 0
            self.restingHR = rhr ?? 0
            self.sleepEffective = sleep.effective
            self.sleepActual = sleep.actual
            self.strain = strain ?? 0
            self.sleepAvg = avgSleep
            
            // Rolling 7‑day baselines
            async let avgHRV = fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: .sevenDaysAgo, end: .now)
            async let avgRHR = fetchAverageQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()), start: .sevenDaysAgo, end: .now)
            async let totalWeekStrain = fetchSumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: .sevenDaysAgo, end: .now)
            
            self.avgHRV = try await avgHRV ?? self.hrv
            self.avgRHR = try await avgRHR ?? self.restingHR
            let weekStrain = try await totalWeekStrain
            self.avgStrain = weekStrain != nil ? weekStrain! / 7.0 : self.strain
            
            // Update adaptive baseline for sleep-based resting HR using exponential moving average
            let defaults = UserDefaults.standard
            let previousBaseline = defaults.double(forKey: baselineKey)
            let newBaseline: Double
            if previousBaseline == 0 {
                // No previous baseline stored
                newBaseline = self.restingHR
            } else {
                // Update baseline with EMA smoothing
                newBaseline = alpha * self.restingHR + (1 - alpha) * previousBaseline
            }
            defaults.set(newBaseline, forKey: baselineKey)
            self.avgRHR = newBaseline // Use adaptive baseline for readiness calculation
            
            Logger.default.info(
                "HRV:\(self.hrv) - RHR:\(self.restingHR) - Sleep:\(self.sleepActual) - Sleep Effective: \(self.sleepEffective) - Strain:\(self.strain) - Consistency:\(self.sleepConsistency ?? 0)"
            )
            Logger.default.info(
                "Average HRV:\(self.avgHRV) - Adaptive Baseline RHR:\(self.avgRHR) - Average Strain:\(self.avgStrain)"
            )
            
            // Calculate readiness using adaptive baseline for restingHR
            self.readinessScore = Int(calculateReadiness())
            publishReadinessScore()
        } catch {
            print("Readiness refresh failed: \(error)")
        }
    }
    
    // MARK: - Calculation
    
    private func calculateReadiness() -> Double {
        // List of all metrics
        let metrics: [ReadinessMetric] = [
            HRVMetric(),
            RHRMetric(),
            SleepMetric(),
            StrainMetric(),
            SleepConsistencyMetric(),
            SleepQualityMetric(),
            HRVTrendMetric(),
            StrainRatioMetric()
        ]
        
        // Weighted sum
        var score = 0.0
        for metric in metrics {
            let metricScore = metric.calculate(readinessManager: self)
            let weighted = metric.weight * metricScore
            score += (metric is StrainMetric) ? -weighted : weighted
            Logger.default
                .debug(
                    "\(metric.name, privacy: .public): score = \(metricScore), weighted = \(weighted)"
                )
        }
        
        return max(0, min(100, score))
    }
    
    func normalize(value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 50 }
        let clamped = Swift.max(Swift.min(value, max), min)
        return ((clamped - min) / (max - min)) * 100
    }
    
    // MARK: - HealthKit Async Helpers
    
    private func fetchAverageQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date = .today, end: Date = .now) async throws -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: id)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let statsDescriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: predicate), options: [.discreteAverage])
        let stats = try await statsDescriptor.result(for: healthStore)
        return stats?.averageQuantity()?.doubleValue(for: unit)
    }
    
    private func fetchSumQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: id)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let statsDescriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: predicate), options: [.cumulativeSum])
        let stats = try await statsDescriptor.result(for: healthStore)
        return stats?.sumQuantity()?.doubleValue(for: unit)
    }
    
    private func fetch7DayAverageSleepHours() async throws -> Double {
        let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let start = Date.sevenDaysAgo
        let end = Date.now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [.init(\.startDate, order: .forward)]
        )
        let samples: [HKCategorySample] = try await descriptor.result(for: healthStore)
        
        // Filter to asleep stages and apply weights
        let asleepTuples = samples.compactMap { sample -> (duration: TimeInterval, weight: Double)? in
            guard let stage = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  HKCategoryValueSleepAnalysis.allAsleepValues.contains(stage) else {
                return nil
            }
            let weight: Double
            switch stage {
            case .asleepDeep: weight = 1.3
            case .asleepREM:  weight = 1.1
            case .asleepCore: weight = 0.9
            default:          weight = 1.0
            }
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            return (duration: duration, weight: weight)
        }
        
        guard !asleepTuples.isEmpty else {
            return 7.0 // fallback to reasonable default (hours)
        }
        
        let totalWeightedSeconds = asleepTuples.reduce(0.0) { $0 + $1.duration * $1.weight }
        // Average per night over 7 days (divide by 7), convert to hours
        let avgHours = (totalWeightedSeconds / 7.0) / 3600.0
        return avgHours
    }
    
    private func fetchSleepDuration(start: Date = .today, end: Date = .now) async throws -> (actual: TimeInterval, effective: TimeInterval) {
        let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.autoupdatingCurrent
        
        // Window: yesterday evening → noon today
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let eveningStart = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: startOfYesterday)!
        let noonToday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        
        let predicate = HKQuery.predicateForSamples(withStart: eveningStart, end: noonToday)
        let samplesDescriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)], sortDescriptors: [.init(\.startDate, order: .forward)])
        let samples: [HKCategorySample] = try await samplesDescriptor.result(for: healthStore)
        
        // Filter to asleep states
        let asleepSamples = samples.compactMap { sample -> (sample: HKCategorySample, weight: Double)? in
            guard let stage = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  HKCategoryValueSleepAnalysis.allAsleepValues.contains(stage) else {
                return nil
            }
            let weight: Double
            switch stage {
            case .asleepDeep: weight = 1.2
            case .asleepREM:  weight = 1.0
            case .asleepCore: weight = 0.8
            default: weight = 1.0
            }
            return (sample, weight)
        }
        
        if !asleepSamples.isEmpty {
            // Merge samples into contiguous blocks
            var mergedBlocks: [(start: Date, end: Date, weightedDuration: Double)] = []
            for item in asleepSamples {
                if let last = mergedBlocks.last, item.sample.startDate.timeIntervalSince(last.end) < 20 * 60 {
                    let weightedDuration = item.sample.endDate.timeIntervalSince(item.sample.startDate) * item.weight
                    mergedBlocks[mergedBlocks.count - 1].end = max(last.end, item.sample.endDate)
                    mergedBlocks[mergedBlocks.count - 1].weightedDuration += weightedDuration
                } else {
                    let weightedDuration = item.sample.endDate.timeIntervalSince(item.sample.startDate) * item.weight
                    mergedBlocks.append((item.sample.startDate, item.sample.endDate, weightedDuration))
                }
            }
            
            let longestBlock = mergedBlocks.max { $0.weightedDuration < $1.weightedDuration }
            return (actual: longestBlock?.end.timeIntervalSince(longestBlock!.start) ?? 0,
                    effective: longestBlock?.weightedDuration ?? 0)
        }
        
        // -------- FALLBACK: HR-BASED ESTIMATION --------
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let hrPredicate = HKQuery.predicateForSamples(withStart: eveningStart, end: noonToday)
        let hrDescriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: hrType, predicate: hrPredicate)],
                                                   sortDescriptors: [.init(\.startDate, order: .forward)])
        let hrSamples: [HKQuantitySample] = try await hrDescriptor.result(for: healthStore)
        
        if !hrSamples.isEmpty {
            let avgHR = hrSamples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }.reduce(0, +) / Double(hrSamples.count)
            let threshold = avgHR - 10 // "Low HR" threshold
            
            var lowBlocks: [(start: Date, end: Date)] = []
            var currentStart: Date? = nil
            
            for sample in hrSamples {
                let hr = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                if hr <= threshold {
                    if currentStart == nil { currentStart = sample.startDate }
                } else {
                    if let start = currentStart {
                        lowBlocks.append((start, sample.startDate))
                        currentStart = nil
                    }
                }
            }
            if let start = currentStart {
                lowBlocks.append((start, hrSamples.last!.endDate))
            }
            
            let longestBlock = lowBlocks.max {
                $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start)
            }
            
            if let block = longestBlock {
                let duration = block.end.timeIntervalSince(block.start)
                return (actual: duration, effective: duration) // no stage weighting available here
            }
        }
        
        // -------- FINAL FALLBACK: 7-DAY AVERAGE --------
        let avgHours = (try? await fetch7DayAverageSleepHours()) ?? 7.0
        return (actual: avgHours * 3600, effective: avgHours * 3600)
    }
    

    /// Fetches the minimum heart rate during the main sleep block (longest sleep block).
    /// Falls back to fetching average resting heart rate if no sleep data is available.
    private func fetchSleepBasedRestingHeartRate() async throws -> Double? {
        // First fetch the main sleep block to get start and end dates
        let sleep = try await fetchSleepDuration()
        guard sleep.actual > 0 else {
            // No sleep data available, fall back to average resting heart rate for today
            return try await fetchAverageQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        }
        
        // To get the main sleep block's start and end, we replicate the merging logic here
        let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.autoupdatingCurrent
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let eveningStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfYesterday)!
        let noonToday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: eveningStart, end: noonToday)
        let samplesDescriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)], sortDescriptors: [.init(\.startDate, order: .forward)])
        let samples: [HKCategorySample] = try await samplesDescriptor.result(for: healthStore)
        let asleepSamples = samples.compactMap { sample -> (sample: HKCategorySample, weight: Double)? in
            guard let stage = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  HKCategoryValueSleepAnalysis.allAsleepValues.contains(stage) else {
                return nil
            }
            let weight: Double
            switch stage {
            case .asleepDeep: weight = 1.2
            case .asleepREM:  weight = 1.0
            case .asleepCore: weight = 0.8
            default:          weight = 1.0
            }
            return (sample, weight)
        }
        var mergedBlocks: [(start: Date, end: Date, weightedDuration: Double)] = []
        for item in asleepSamples {
            if let last = mergedBlocks.last, item.sample.startDate.timeIntervalSince(last.end) < 20 * 60 {
                mergedBlocks[mergedBlocks.count - 1].end = max(last.end, item.sample.endDate)
                let weightedDuration = item.sample.endDate.timeIntervalSince(item.sample.startDate) * item.weight
                mergedBlocks[mergedBlocks.count - 1].weightedDuration += weightedDuration
            } else {
                mergedBlocks.append((item.sample.startDate, item.sample.endDate, 0))
            }
        }
        guard let mainSleepBlock = mergedBlocks.max(by: { $0.weightedDuration < $1.weightedDuration }) else {
            // No merged blocks found, fallback
            return try await fetchAverageQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        }
        
        // Query heart rate samples during main sleep block
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let hrPredicate = HKQuery.predicateForSamples(withStart: mainSleepBlock.start, end: mainSleepBlock.end)
        let hrSamplesDescriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: hrType, predicate: hrPredicate)], sortDescriptors: [.init(\.startDate, order: .forward)])
        let hrSamples: [HKQuantitySample] = try await hrSamplesDescriptor.result(for: healthStore)
        
        // Find minimum heart rate during sleep block
        let minHR = hrSamples.map { $0.quantity.doubleValue(for: .count().unitDivided(by: .minute())) }.min()
        
        if let minHR = minHR {
            return minHR
        } else {
            // No heart rate samples during sleep block, fallback to resting heart rate average
            return try await fetchAverageQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        }
    }
}


extension ReadinessManager {
    /// Call at the end of `refresh()` after you set `self.readinessScore`.
    func publishReadinessScore() {
        let score = self.readinessScore
        SharedReadinessStore.save(score: score)
        
        // Also broadcast over WatchConnectivity so the paired device updates immediately.
        let payload: [String: Any] = [
            "type": "readinessUpdate",
            "score": score,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        ConnectivityBridge.shared.send(payload: payload)
        Logger.default.debug("Published readiness score \(score)")
    }
    
    static func nextUpdateDate(avoidSleepWindow: Bool) -> Date {
        let now = Date()
        guard avoidSleepWindow else { return now.addingTimeInterval(60 * 30) }
        
        let cal = Calendar.current
        let todays10pm = cal.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
        let tomorrow510 = cal.date(bySettingHour: 5, minute: 10, second: 0, of: now.addingTimeInterval(86400))!
        
        if now >= todays10pm {
            return tomorrow510 // overnight → next morning
        } else if now < cal.date(bySettingHour: 5, minute: 10, second: 0, of: now)! {
            // before 5:10 today → set to 5:10 today
            return cal.date(bySettingHour: 5, minute: 10, second: 0, of: now)!
        } else {
            // daytime: periodic refresh
            return now.addingTimeInterval(60 * 30)
        }
    }
}

extension ReadinessManager {
    var hrvDelta: Double {
        return hrv - avgHRV
    }
    
    var sleepDelta: Double {
        return sleepActual - sleepAvg
    }
    
}


extension Date {
    static var now: Date { Date() }
    static var today: Date { Calendar.current.startOfDay(for: .now) }
    static var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: .today)! }
    static var yesterdayEnd: Date { Calendar.current.date(byAdding: .day, value: 1, to: .yesterday)! }
    static var sevenDaysAgo: Date { Calendar.current.date(byAdding: .day, value: -7, to: .now)! }
}
