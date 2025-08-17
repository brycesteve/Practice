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

enum ExerciseModality: Codable, Equatable {
    case count(reps: Int)
    case timed(duration: Duration)
}

enum Exercise: Codable, Equatable {
    case squat (modality: ExerciseModality, weight: Int)
    case hipRaise (modality: ExerciseModality)
    case halo (modality: ExerciseModality, weight: Int)
    
    case swing (modality: ExerciseModality, weight: Int, hand: Handedness)
    case getUp (modality: ExerciseModality, weight: Int, hand: Handedness)
    
    case rest
    
    case ninetyNinety (modality: ExerciseModality, side: Handedness)
    case qlStraddle (modality: ExerciseModality, side: Handedness)
    
    //TODO: Make these into a superset
    case elevatedPushUp (modality: ExerciseModality)
    case pullUp (modality: ExerciseModality)
    
    case deepSquatHold (modality: ExerciseModality)
    case hipFlexorStretch (modality: ExerciseModality, side: Handedness)
    case hamstringStretch (modality: ExerciseModality, side: Handedness)
    case splits (modality: ExerciseModality)
    case bridge (modality: ExerciseModality)
    case hang(modality: ExerciseModality)
    
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
    #if os(watchOS)
    var hapticType: WKHapticType {
        switch self {
        case .rest:
            return .directionDown
        default:
            return .directionUp
        }
    }
    #endif
    
 
    var description: String {
        switch self {
        case let .squat(_, weight),
            let .halo(_, weight):
            return self.name + " \(weight)Kg"
        case let .swing(_, weight, hand),
        let .getUp(_, weight, hand):
            return "\(self.name) - \(hand) - \(weight)Kg"
        case let .hamstringStretch(_, side),
            let .hipFlexorStretch(_,side):
            return "\(self.name) - \(side)"
        case .rest,
        .elevatedPushUp,
        .hipRaise,
        .pullUp,
        .ninetyNinety,
        .deepSquatHold,
        .splits,
        .bridge,
        .qlStraddle,
        .hang:
            return self.name
        }
    }
    
    var repsOrDuration: String {
        switch self {
        case .rest:
            return ""
        case let .bridge(modality),
            let .deepSquatHold(modality),
            let .elevatedPushUp(modality),
            let .getUp(modality, _, _),
            let .halo(modality, _),
            let .hamstringStretch(modality, _),
            let .hang(modality),
            let .hipFlexorStretch(modality, _),
            let .hipRaise(modality),
            let .ninetyNinety(modality, _),
            let .pullUp(modality),
            let .qlStraddle(modality, _),
            let .splits(modality),
            let .squat(modality, _),
            let .swing(modality, _, _):
            switch modality {
            case let .count(reps):
                return "\(reps)x"
            case let .timed(duration):
                return "\(duration.formatted(.units(width: .narrow)))"
            }
        }
    }
    
    var modality: ExerciseModality? {
        switch self {
        case .rest:
            return nil
        case let .bridge(modality),
            let .deepSquatHold(modality),
            let .elevatedPushUp(modality),
            let .getUp(modality, _, _),
            let .halo(modality, _),
            let .hamstringStretch(modality, _),
            let .hang(modality),
            let .hipFlexorStretch(modality, _),
            let .hipRaise(modality),
            let .ninetyNinety(modality, _),
            let .pullUp(modality),
            let .qlStraddle(modality, _),
            let .splits(modality),
            let .squat(modality, _),
            let .swing(modality, _, _):
            return modality
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
    
    static func from(_ event: HKWorkoutEvent) -> Self? {
        guard let metaString = event.metadata?[Exercise.metadataKey] as? String,
              let data = Data(base64Encoded: metaString),
              let exercise = try? JSONDecoder().decode(Exercise.self, from: data)
        else {
            return nil
        }
        return exercise
    }
}
