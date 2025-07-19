//
//  UserDefaults+extension.swift
//  Practice
//
//  Created by Steve Bryce on 12/07/2025.
//
import Foundation



extension UserDefaults {
    static var twoHandedSwingsKey: String { "twoHandedSwings" }
    var twoHandedSwings: Bool {
        get {
            bool(forKey: Self.twoHandedSwingsKey)
        } set {
            set(newValue, forKey: Self.twoHandedSwingsKey)
        }
    }
    
}

