//
//  SinisterKettlebell.swift
//  Practice
//
//  Created by Steve Bryce on 24/05/2025.
//

import HealthKit
import SwiftUI

enum Handedness: String, Codable {
    case left
    case right
    case twoHanded
}

enum Exercise: Codable, Equatable {
    case squat (reps: Int, weight: Int)
    case hipRaise (reps: Int)
    case halo (reps: Int, weight: Int)
    
    case swing (reps: Int, weight: Int, hand: Handedness)
    case getUp (reps: Int, weight: Int, hand: Handedness)
    
    case rest
    
    case ninetyNinety (duration: Duration, side: Handedness)
    case qlStraddle (duration: Duration, side: Handedness)
    
    static var metadataKey: String { "net.stevebryce.ExerciseMeta" }
    
    var name: String {
        switch self {
        case .squat:
            "Prying Goblet Squat"
        case .hipRaise:
            "Hip Raise"
        case .halo:
            "Halo"
        case .swing:
            "Swing"
        case .getUp:
            "Get Up"
        case .rest: "Rest"
        case .ninetyNinety: "90 90 Stretch"
        case .qlStraddle: "QL Straddle"
        }
    }
 
    var description: String {
        switch self {
        case let .squat(reps, _),
        let .hipRaise(reps),
        let .halo(reps, _):
            return "\(reps)x " + self.name
        case let .swing(reps, _, hand),
        let .getUp(reps, _, hand):
            return "\(reps)x " + self.name + " - \(hand)"
        case .rest,
        .ninetyNinety,
        .qlStraddle:
            return self.name
        }
    }
    
    var weight: Int? {
        switch self {
        case let .squat(_, weight),
        let .halo(_, weight),
        let .swing(_, weight, _),
        let .getUp(_, weight, _):
            return weight
        default:
            return nil
        }
    }
    
    
    
    enum CodingKeys: String, CodingKey {
        case squat = "squat"
        case hipRaise = "hipRaise"
        case halo = "halo"
        case swing = "swing"
        case getUp = "getUp"
        case rest = "rest"
        case ninetyNinety = "ninetyNinety"
        case qlStraddle = "qlStraddle"
    }
    
    static func from(_ activity: HKWorkoutActivity) -> Self? {
        guard let metaString = activity.metadata?[Exercise.metadataKey] as? String,
              let data = Data(base64Encoded: metaString),
              let exercise = try? JSONDecoder().decode(Exercise.self, from: data)
        else {
            return nil
        }
        return exercise
    }
}
