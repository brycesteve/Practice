//
//  PracticeEntity.swift
//  Practice
//
//  Created by Steve Bryce on 26/07/2025.
//


import AppIntents

struct PracticeEntity: AppEntity, Identifiable {
    static var defaultQuery = PracticeQuery()
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Practice")

    // Unique ID for each practice
    var id: String { name }

    // Actual properties
    var name: String
    
    // How this item appears in Siri/Shortcuts UI
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(Practice(rawValue: name)!.name)")
    }
}
