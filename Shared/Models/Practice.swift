//
//  Practice.swift
//  Practice
//
//  Created by Steve Bryce on 24/05/2025.
//
import HealthKit
import SwiftUI

/*
 Core enum for practice structure
 */
enum Practice: String, Codable, CaseIterable {
    case SimpleAndSinister = "Simple and Sinister"
    case SimpleAndSinisterStretches = "S&S Stretches"
    
    var workoutType: HKWorkoutActivityType {
        switch self {
        case .SimpleAndSinister:
            return .functionalStrengthTraining
        case .SimpleAndSinisterStretches:
            return .flexibility
        }
    }
    
    var segmentOrder: [String: Int] {
        switch self {
        case .SimpleAndSinister:
            return SimpleSinisterSegment.segmentOrder
        case .SimpleAndSinisterStretches:
            return SimpleSinisterStretchesSegment.segmentOrder
        }
    }
    
    
    var name: String {
        switch self {
        case .SimpleAndSinister: return "Simple and Sinister+"
        case .SimpleAndSinisterStretches: return "Stretches"
        }
    }
    
    var segments: [PracticeSegment] {
        switch self {
        case .SimpleAndSinister:
            return [
                SimpleSinisterSegment.warmUp,
                SimpleSinisterSegment.swings,
                SimpleSinisterSegment.getUps,
                SimpleSinisterSegment.push,
                SimpleSinisterSegment.pull
            ]
        case .SimpleAndSinisterStretches:
            return [SimpleSinisterStretchesSegment.stretches]
        }
    }
    
    var image: Image {
        switch self {
        case .SimpleAndSinister:
            return Image(.kettlebellFlat)
        case .SimpleAndSinisterStretches:
            return Image(systemName: "figure.cooldown")
        }
    }
    
#if os(watchOS)
    var settingsView: (any View)? {
        switch self {
        case .SimpleAndSinister:
            return SimpleSinisterSettingsView()
        default:
            return nil
        }
    }
#endif // os(watchOS)
}

extension Practice: Hashable, Identifiable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    var id: String { name }
}



