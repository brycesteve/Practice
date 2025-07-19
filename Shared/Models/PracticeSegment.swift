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
                Exercise.ninetyNinety(duration: .seconds(60), side: .left),
                Exercise.ninetyNinety(duration: .seconds(60), side: .right),
                Exercise.qlStraddle(duration: .seconds(60), side: .left),
                Exercise.qlStraddle(duration: .seconds(60), side: .right),
                Exercise.ninetyNinety(duration: .seconds(60), side: .left),
                Exercise.ninetyNinety(duration: .seconds(60), side: .right),
                Exercise.qlStraddle(duration: .seconds(60), side: .left),
                Exercise.qlStraddle(duration: .seconds(60), side: .right)
            ]
        }
    }
    

}

enum SimpleSinisterSegment: PracticeSegment {
    case warmUp
    case swings
    case getUps
    
    static var segmentOrder: [String: Int] {
        return [
            "Warm Up": 0,
            "Swings": 1,
            "Get Ups": 2
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
            ], count: 5).flatMap { $0 }.dropLast()
        }
    }
}
