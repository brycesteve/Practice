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
    
    case elevatedPushUp (reps: Int)
    case pullUp (reps: Int)
    
    case deepSquatHold (duration: Duration)
    case hipFlexorStretch (duration: Duration, side: Handedness)
    case hamstringStretch (duration: Duration, side: Handedness)
    case splits (duration: Duration)
    case bridge (duration: Duration)
    case hang(duration: Duration)
    
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
        case .elevatedPushUp:
            "Decline Pushup"
        case .pullUp:
            "Pull up"
        case .deepSquatHold:
            "Squat Hold"
        case .hipFlexorStretch:
            "Hip Flexor Stretch"
        case .hamstringStretch:
            "Hamstring Stretch"
        case .splits:
            "Splits"
        case .bridge:
            "Bridge"
        case .hang:
            "Bar Hang"
        }
    }
 
    var description: String {
        switch self {
        case let .squat(reps, _),
        let .hipRaise(reps),
        let .halo(reps, _),
        let .pullUp(reps),
        let .elevatedPushUp(reps):
            return "\(reps)x " + self.name
        case let .swing(reps, _, hand),
        let .getUp(reps, _, hand):
            return "\(reps)x " + self.name + " - \(hand)"
        case let .hamstringStretch(_, side),
            let .hipFlexorStretch(_,side):
            return "\(self.name) - \(side)"
        case .rest,
        .ninetyNinety,
        .deepSquatHold,
        .splits,
        .bridge,
        .qlStraddle,
        .hang:
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
        case deepSquatHold = "deepSquatHold"
        case pullUp = "pullUp"
        case elevatedPushUp = "elevatedPushUp"
        case hipFlexorStretch = "hipFlexorStretch"
        case hamstringStretch = "hamstringStretch"
        case splits = "splits"
        case bridge = "bridge"
        case hang = "hang"
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
