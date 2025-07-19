////
////  CompletedPractice.swift
////  Practice
////
////  Created by Steve Bryce on 31/05/2025.
////
//
//import SwiftUI
//import HealthKit
//import Foundation
//
//
//
//struct CompletedPractice: Hashable & Identifiable, Codable {
//    static var metadataKey: String = "PracticeMeta"
//    
//    var name: String
//    
//    var date: Date = .now
//    
//    var sets: [CompletedPracticeSet] = []
//    
//    var type: String?
//    
//    init(name: String, date: Date = .now, type: String? = nil, sets: [CompletedPracticeSet] = [], iconName: String? = nil, systemIconName: String? = nil) {
//        self.name = name
//        self.date = date
//        self.type = type
//        self.sets = sets
//        self.iconName = iconName
//        self.systemIconName = systemIconName
//    }
//    
//    var iconName: String? = nil
//    var systemIconName: String? = nil
//    
//    var image: Image {
//        if let iconName {
//            return Image(iconName)
//        }
//        if let systemIconName {
//            return Image(systemName: systemIconName)
//        }
//        return Image(.kettlebellFlat)
//    }
//    
//    /**
//     Creates a CompletedPractice from Encoded JsonString
//     - Parameter from: A JSON encoded string
//     */
//    init?(from: String) {
//        let decoder = JSONDecoder()
//        let data = from.data(using: .utf8)
//        if let object = try? decoder.decode(CompletedPractice.self, from: data!) {
//            self.name = object.name
//            self.date = object.date
//            self.sets = object.sets
//            self.type = object.type
//            self.iconName = object.iconName
//            self.systemIconName = object.systemIconName
//        }
//        else {
//            return nil
//        }
//    }
//    
//}
//
//extension CompletedPractice {
//    static func == (lhs: Self, rhs: Self) -> Bool { lhs.date == rhs.date }
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(date)
//    }
//    var id: Date { date }
//}
//
//struct CompletedPracticeSet: Codable {
//    var reps: Int
//    var weight: Int?
//    var handedness: Handedness = .none
//    var type: SinisterKettlebellPracticeType
//    var duration: TimeInterval
//    var lowHR: Int?
//    var highHR: Int?
//}
