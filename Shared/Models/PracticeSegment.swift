//
//  PracticeSegment.swift
//  Practice
//
//  Created by Steve Bryce on 12/07/2025.
//

import Foundation
import WorkoutKit
import HealthKit

let PracticeSegmentNameMetaDataKey: String = "net.stevebryce.ExerciseSegment"

protocol PracticeSegment {
    var name: String { get }
    var sets: [Exercise] { get }
    
    static var segmentOrder: [String: Int] { get }
    
    //var goal: WorkoutGoal { get }
    
    var segmentExerciseType: HKWorkoutActivityType { get }
}

enum SimpleSinisterStretchesSegment: PracticeSegment {
    case stretches
    
    static var segmentOrder: [String: Int] {
        return [
            "Stretches": 1
        ]
    }
    
    var segmentExerciseType: HKWorkoutActivityType {
        return .flexibility
    }
    
    var name: String {
        switch self {
        case .stretches:
            return "Stretches"
        }
    }
    
    var sets: [Exercise] {
        switch self {
        case .stretches:
            return [
            Exercise.deepSquatHold(modality: .timed(duration: .seconds(120))),
            Exercise.ninetyNinety(modality: .timed(duration: .seconds(60)), side: .left),
            Exercise.ninetyNinety(modality: .timed(duration: .seconds(60)), side: .right),
            Exercise.qlStraddle(modality: .timed(duration: .seconds(60)), side: .left),
            Exercise.qlStraddle(modality: .timed(duration: .seconds(60)), side: .right),
            Exercise.hipFlexorStretch(modality: .timed(duration: .seconds(60)), side: .left),
            Exercise.hipFlexorStretch(modality: .timed(duration: .seconds(60)), side: .right),
            Exercise.hamstringStretch(modality: .timed(duration: .seconds(60)), side: .left),
            Exercise.hamstringStretch(modality: .timed(duration: .seconds(60)), side: .right),
            Exercise.splits(modality: .timed(duration: .seconds(120))),
            Exercise.bridge(modality: .timed(duration: .seconds(30))),
            Exercise.hang(modality: .timed(duration: .seconds(30))),
                Exercise.rest,
            Exercise.hang(modality: .timed(duration: .seconds(30)))
            ]
        }
    }
    

}

enum SimpleSinisterSegment: PracticeSegment {
    case warmUp
    case swings
    case getUps
    case push
    case pull
    case pushPull
    
    static var segmentOrder: [String: Int] {
        return [
            "Warm Up": 0,
            "Swings": 1,
            "Get Ups": 2,
            "Push": 3,
            "Pull": 4,
            "PushPull": 5
        ]
    }
    
    var segmentExerciseType: HKWorkoutActivityType {
        switch self {
        case .warmUp:
            return .preparationAndRecovery
        case .swings:
            return .functionalStrengthTraining
        case .getUps:
            return .functionalStrengthTraining
        case .push:
            return .functionalStrengthTraining
        case .pull:
            return .functionalStrengthTraining
        case .pushPull:
            return .functionalStrengthTraining
        
        }
    }
    
    var name: String {
        switch self {
        case .warmUp:
            return "Warm Up"
        case .swings:
            return "Swings"
        case .getUps:
            return "Get Ups"
        case .push:
            return "Push"
        case .pull:
            return "Pull"
        case .pushPull:
            return "Push/Pull"
        }
    }
    
    var sets: [Exercise] {
        switch self {
        case .warmUp:
            return [[Exercise]](repeating: [
                Exercise.squat(modality: .count(reps: 5), weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.squat.rawValue)),
                Exercise.hipRaise(modality: .count(reps: 5)),
                Exercise.halo(modality: .count(reps: 10), weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.halo.rawValue)),
                Exercise.rest
            ], count: 3).flatMap { $0 }
            
        case .swings:
            let twoHanded = UserDefaults.standard.twoHandedSwings
            return [[Exercise]](repeating: [
                Exercise.swing(modality: .count(reps: 10), weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.swing.rawValue), hand: twoHanded ? .twoHanded : .left),
                Exercise.rest,
                Exercise.swing(modality: .count(reps: 10), weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.swing.rawValue), hand: twoHanded ? .twoHanded : .right),
                Exercise.rest
            ], count: 5).flatMap { $0 }
        case .getUps:
            return [[Exercise]](repeating: [
                Exercise.getUp(modality: .count(reps: 1), weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.getUp.rawValue), hand: .left),
                Exercise.rest,
                Exercise.getUp(modality: .count(reps: 1), weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.getUp.rawValue), hand: .right),
                Exercise.rest
            ], count: 5).flatMap { $0 }
            
        case .push:
            // TODO: Add reps to settings
            return [[Exercise]](repeating: [
                Exercise.elevatedPushUp(modality: .count(reps: 10)),
                Exercise.rest
            ], count: 3).flatMap { $0 }
            
        case .pull:
            // TODO: Add reps to settings
            return [[Exercise]](repeating: [
                Exercise.pullUp(modality: .count(reps: 5)),
                Exercise.rest
            ], count: 3).flatMap { $0 }
            
        case .pushPull:
            return [[Exercise]](repeating: [
                Exercise.elevatedPushUp(modality: .count(reps: 10)),
                Exercise.pullUp(modality: .count(reps: 5)),
                Exercise.rest
            ], count: 3).flatMap { $0 }.dropLast()
        }
    }
}
