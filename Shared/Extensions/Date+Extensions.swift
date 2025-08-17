//
//  Date+Extensions.swift
//  Practice
//
//  Created by Steve Bryce on 02/08/2025.
//
import Foundation

extension Date {
    func startOfWeek(using calendar: Calendar = .autoupdatingCurrent) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }
    
    func weekRangeLabel(using calendar: Calendar = .autoupdatingCurrent) -> String {
        let start = self
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        
        let formatter = DateFormatter()
        formatter.locale = .current
        
        // If start and end are in same month: "22–28 Jul"
        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            formatter.dateFormat = "d"
            let startDay = formatter.string(from: start)
            formatter.dateFormat = "d MMM"
            let endDay = formatter.string(from: end)
            return "\(startDay)–\(endDay)"
        } else {
            // If they span months: "28 Jun – 4 Jul"
            formatter.dateFormat = "d MMM"
            let startDay = formatter.string(from: start)
            let endDay = formatter.string(from: end)
            return "\(startDay) – \(endDay)"
        }
    }
}
