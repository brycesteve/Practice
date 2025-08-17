//
//  ReadinessMetrics.swift
//  Practice
//
//  Created by Steve Bryce on 16/08/2025.
//

import OSLog

struct SleepQualityMetric: @MainActor ReadinessMetric {
    let name = "Sleep Quality"
    let weight = 0.10
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        guard readinessManager.sleepActual > 0 else { return 100 } // fallback
        let efficiency = readinessManager.sleepEffective / readinessManager.sleepActual
        return max(0, min(100, efficiency * 100))
    }
}

struct StrainRatioMetric: @MainActor ReadinessMetric {
    let name = "Strain Ratio"
    let weight = 0.05
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        guard readinessManager.avgStrain > 0 else { return 100 }
        let ratio = readinessManager.strain / readinessManager.avgStrain
        // Ratio > 1 means overreaching → reduce score
        let adjusted = ratio <= 1 ? 1.0 : 1.0 / ratio
        return max(0, min(100, adjusted * 100))
    }
}

struct HRVTrendMetric: @MainActor ReadinessMetric {
    let name = "HRV Trend"
    let weight = 0.05
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        let avgHRV = readinessManager.avgHRV
        let todayHRV = readinessManager.hrv
        guard avgHRV > 0 else { return 100 }
        let trendRatio = todayHRV / avgHRV
        return max(0, min(100, trendRatio * 100))
    }
}

struct HRVMetric: @MainActor ReadinessMetric {
    let name = "HRV"
    let weight = 0.2
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        let score = readinessManager.normalize(
            value: readinessManager.hrv,
            min: readinessManager.avgHRV * 0.5,
            max: readinessManager.avgHRV * 1.2
        )
        return score
    }
}

struct RHRMetric: @MainActor ReadinessMetric {
    let name = "Resting HR"
    let weight = 0.25
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        readinessManager.normalize(
            value: readinessManager.avgRHR * 1.2 - readinessManager.restingHR,
            min: 0,
            max: readinessManager.avgRHR * 0.4
        )
    }
}

struct SleepMetric: @MainActor ReadinessMetric {
    let name = "Sleep"
    let weight = 0.2
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        readinessManager.normalize(
            value: readinessManager.sleepEffective,
            min: 5 * 3600,
            max: 8 * 3600
        )
    }
}

struct StrainMetric: @MainActor ReadinessMetric {
    let name = "Strain"
    let weight = 0.1 // penalty factor
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        readinessManager.normalize(
            value: readinessManager.strain,
            min: readinessManager.avgStrain,
            max: readinessManager.avgStrain * 1.5
        )
    }
}

struct SleepConsistencyMetric: @MainActor ReadinessMetric {
    let name = "Sleep Consistency"
    let weight = 0.05  // Adjust as needed
    
    @MainActor func calculate(readinessManager: ReadinessManager) -> Double {
        // Because this is async, for simplicity here we can assume readinessManager prefetches the value
        return readinessManager.sleepConsistency ?? 100
    }
}
