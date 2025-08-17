//
//  ReadinessMetric.swift
//  Practice
//
//  Created by Steve Bryce on 16/08/2025.
//


import Foundation

protocol ReadinessMetric {
    /// Name of the metric (for logging/UI)
    var name: String { get }

    /// Weight in final readiness score (0–1, sum should ideally be 1)
    var weight: Double { get }

    /// Calculates a normalized score 0–100 for this metric
    func calculate(readinessManager: ReadinessManager) -> Double
}