//
//  WorkoutEngine.swift
//  Practice
//
//  Created by Steve Bryce on 26/04/2026.
//


actor WorkoutEngine {
    private var isActive = false

    func markStarted() {
        isActive = true
    }

    func markEnded() {
        isActive = false
    }
}