//
//  Logger.swift
//  Practice
//
//  Created by Steve Bryce on 24/05/2025.
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Practice"
    
    static let `default` = Logger(subsystem: subsystem, category: "default")
    
}

