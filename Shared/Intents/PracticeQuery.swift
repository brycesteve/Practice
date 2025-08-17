//
//  PracticeQuery.swift
//  Practice
//
//  Created by Steve Bryce on 26/07/2025.
//
import AppIntents

struct PracticeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PracticeEntity] {
        availablePractices().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PracticeEntity] {
        availablePractices()
    }
    
    private func availablePractices() -> [PracticeEntity] {
        Practice.allCases.map{ PracticeEntity(name: $0.rawValue) }
    }
}
