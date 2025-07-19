//
//  Calendar+Extensions.swift
//  Practice
//
//  Created by Steve Bryce on 15/06/2025.
//

import Foundation

extension Calendar {
    var shortWeekdaySymbolsOrdered: [String] {
        orderedWeekdays(from: self.shortWeekdaySymbols)
    }
    
    var veryShortWeekdaySymbolsOrdered: [String] {
        orderedWeekdays(from: self.veryShortWeekdaySymbols)
    }
    
    private func orderedWeekdays (from symbols: [String]) -> [String] {
        Array(symbols[self.firstWeekday-1..<symbols.count]) + symbols[0..<firstWeekday-1]
    }
}



