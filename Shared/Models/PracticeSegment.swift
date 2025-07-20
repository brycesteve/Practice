//
//  PracticeSegment.swift
//  Practice
//
//  Created by Steve Bryce on 12/07/2025.
//

import Foundation

let PracticeSegmentNameMetaDataKey: String = "net.stevebryce.ExerciseSegment"

protocol PracticeSegment {
    var name: String { get }
    var sets: [Exercise] { get }
    
    static var segmentOrder: [String: Int] { get }
}

enum SimpleSinisterStretchesSegment: PracticeSegment {
    case stretches
    
    static var segmentOrder: [String: Int] {
        return [
            "Stretches": 1
        ]
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
                Exercise.deepSquatHold(duration: .seconds(120)),
                Exercise.ninetyNinety(duration: .seconds(60), side: .left),
                Exercise.ninetyNinety(duration: .seconds(60), side: .right),
                Exercise.qlStraddle(duration: .seconds(60), side: .left),
                Exercise.qlStraddle(duration: .seconds(60), side: .right),
                Exercise.hipFlexorStretch(duration: .seconds(60), side: .left),
                Exercise.hipFlexorStretch(duration: .seconds(60), side: .right),
                Exercise.hamstringStretch(duration: .seconds(60), side: .left),
                Exercise.hamstringStretch(duration: .seconds(60), side: .right),
                Exercise.splits(duration: .seconds(120)),
                Exercise.bridge(duration: .seconds(30)),
                Exercise.hang(duration: .seconds(30)),
                Exercise.rest,
                Exercise.hang(duration: .seconds(30))
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
    
    static var segmentOrder: [String: Int] {
        return [
            "Warm Up": 0,
            "Swings": 1,
            "Get Ups": 2,
            "Push": 3,
            "Pull": 4
        ]
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
        }
    }
    
    var sets: [Exercise] {
        switch self {
        case .warmUp:
            return [[Exercise]](repeating: [
                Exercise.squat(reps: 5, weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.squat.rawValue)),
                Exercise.hipRaise(reps: 5),
                Exercise.halo(reps: 10, weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.halo.rawValue)),
                Exercise.rest
            ], count: 3).flatMap { $0 }
            
        case .swings:
            let twoHanded = UserDefaults.standard.twoHandedSwings
            return [[Exercise]](repeating: [
                Exercise.swing(reps: 10, weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.swing.rawValue), hand: twoHanded ? .twoHanded : .left),
                Exercise.rest,
                Exercise.swing(reps: 10, weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.swing.rawValue), hand: twoHanded ? .twoHanded : .right),
                Exercise.rest
            ], count: 5).flatMap { $0 }
        case .getUps:
            return [[Exercise]](repeating: [
                Exercise.getUp(reps: 1, weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.getUp.rawValue), hand: .left),
                Exercise.rest,
                Exercise.getUp(reps: 1, weight: UserDefaults.standard.integer(forKey: Exercise.CodingKeys.getUp.rawValue), hand: .right),
                Exercise.rest
            ], count: 5).flatMap { $0 }
            
        case .push:
            // TODO: Add reps to settings
            return [[Exercise]](repeating: [
                Exercise.elevatedPushUp(reps: 10),
                Exercise.rest
            ], count: 3).flatMap { $0 }
            
        case .pull:
            // TODO: Add reps to settings
            return [[Exercise]](repeating: [
                Exercise.pullUp(reps: 5),
                Exercise.rest
            ], count: 3).flatMap { $0 }.dropLast()
        }
    }
}
