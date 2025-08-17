//
//  HealthKit+Extensions.swift
//  Practice
//
//  Created by Steve Bryce on 22/06/2025.
//

import HealthKit

extension HKObjectType {
    static var typesToShare: Set<HKSampleType> {
        [
            .quantityType(forIdentifier: .estimatedWorkoutEffortScore)!,
            .workoutType(),
        ]
    }

    // The quantity types to read from the health store.
    static var typesToRead: Set<HKObjectType> {
        [
            .workoutType(),
            .quantityType(forIdentifier: .heartRate)!,
            .quantityType(forIdentifier: .activeEnergyBurned)!,
            .activitySummaryType(),
            .characteristicType(forIdentifier: .dateOfBirth)!,
            .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            .quantityType(forIdentifier: .restingHeartRate)!,
            .categoryType(forIdentifier: .sleepAnalysis)!,
            .quantityType(forIdentifier: .vo2Max)!
        ]
    }
}

struct WorkRestRatio {
    let workTime: TimeInterval
    let restTime: TimeInterval
    var ratio: Double {
        workTime / (workTime + restTime)
    }
}

struct WeeklyMetrics: Identifiable {
    var id: Date { weekStart }
    let weekStart: Date
    let work: TimeInterval
    let rest: TimeInterval
    let tonnage: Int
    
    var ratio: Double {
        let total = work + rest
        return total > 0 ? work / total : 0
    }
    
    var changeFromLast: Double? = nil
}



extension HKWorkout {
    var brandName: String? {
        return metadata?[HKMetadataKeyWorkoutBrandName] as? String
    }
    
    var segments: [HKWorkoutActivity] {
        guard !workoutActivities.isEmpty else { return [] }
        return workoutActivities
    }
    
    var simpleAndSinisterWeight: Int {
        guard metadata?[HKMetadataKeyWorkoutBrandName] as? String == Practice.SimpleAndSinister.rawValue,
              let workoutEvents = workoutEvents, workoutEvents.count > 0
        else {
            return 0
        }
        let exercises = workoutEvents.filter { event in
                event.type == .segment
        }.compactMap { event in
            return Exercise.from(event)
        }.filter {
            if case .swing = $0 { return true }
            if case .getUp = $0 { return true }
            return false
        }
        
        let weight = exercises.reduce(into: 0) {
            switch $1 {
            case let .swing(.count(reps), weight, _),
                let .getUp(.count(reps), weight, _):
                $0 += (weight * reps)
            default:
                return
            }
        }
        return weight
    }
    
    var workToRestRatio: WorkRestRatio {
        guard let events = workoutEvents else {
            return WorkRestRatio(workTime: 0, restTime: 0)
        }

        var work: TimeInterval = 0
        var rest: TimeInterval = 0
        
        for event in events where event.type == .segment {
            let duration = event.dateInterval.duration
            let exercise = Exercise.from(event)
            let isRest = exercise == .rest
            
            if isRest {
                rest += duration
            } else {
                work += duration
            }
        }
        
        return WorkRestRatio(workTime: work, restTime: rest)
    }
}

extension HKWorkoutActivity {
    var segmentName: String {
        return metadata?[PracticeSegmentNameMetaDataKey] as? String ?? "Segment"
    }
    
    var exerciseEvents: [HKWorkoutEvent] {
        return workoutEvents.filter { event in
            event.type == .segment
        }
    }
    
    var workToRestRatio: WorkRestRatio {
        var work: TimeInterval = 0
        var rest: TimeInterval = 0
        
        for event in workoutEvents where event.type == .segment {
            let duration = event.dateInterval.duration
            let exercise = Exercise.from(event)
            let isRest = exercise == .rest
            
            if isRest {
                rest += duration
            } else {
                work += duration
            }
        }
        
        return WorkRestRatio(workTime: work, restTime: rest)
    }
}


struct Streak {
    let length: Int
    let start: Date?
    let end: Date?

    var dateRange: String {
        guard let start, let end else { return "No streak" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
extension Collection where Element == HKWorkout {
    func calculateLongestComplianceWorkoutStreak() -> Streak {
        let restDays = 2
        let calendar = Calendar.autoupdatingCurrent
        let workoutDays = Set(self
            .map { calendar.startOfDay(for: $0.startDate) })
            .sorted()

        guard !workoutDays.isEmpty else { return Streak(length: 0, start: nil, end: nil) }

        var longestStreakLength = 1
        var longestStart: Date? = workoutDays.max()
        var longestEnd: Date? = workoutDays.max()

        // Try every possible starting workout day
        for i in 0..<workoutDays.count {
            var currentStreakDays: [Date] = [workoutDays[i]]
            var endIndex = i

            while endIndex + 1 < workoutDays.count {
                let nextWorkoutDay = workoutDays[endIndex + 1]
                currentStreakDays.append(nextWorkoutDay)

                guard let first = currentStreakDays.first,
                      let last = currentStreakDays.last,
                      let totalDays = calendar.dateComponents([.day], from: first, to: last).day else {
                    break
                }

                let calendarRange: [Date] = (0...totalDays).compactMap {
                    calendar.date(byAdding: .day, value: $0, to: first)
                }

                let workoutSet = Set(currentStreakDays)
                let isValid = calendarRange.indices.allSatisfy { idx in
                    guard idx + 6 < calendarRange.count else { return true }
                    let window = calendarRange[idx...idx + 6]
                    let restCount = window.filter { !workoutSet.contains($0) }.count
                    return restCount <= restDays
                }

                if isValid {
                    let currentLength = currentStreakDays.count
                    if currentLength > longestStreakLength {
                        longestStreakLength = currentLength
                        longestStart = first
                        longestEnd = last
                    }
                    endIndex += 1
                } else {
                    break
                }
            }
        }

        return Streak(length: longestStreakLength, start: longestStart, end: longestEnd)
    }
    
    func calculateCurrentComplianceWorkoutStreak() -> Streak {
        let maxRestDaysPer7 = 2
        let calendar = Calendar.current

        let workoutDays = Set(self
            .map { calendar.startOfDay(for: $0.startDate) })
            .sorted()
        
        let referenceDate = Date()

        guard !workoutDays.isEmpty else { return Streak(length: 0, start: nil, end: nil) }

        let today = calendar.startOfDay(for: referenceDate)

        // Only consider workouts on or before today
        let filtered = workoutDays.filter { $0 <= today }
        guard let lastWorkoutDay = filtered.last, lastWorkoutDay >= calendar.date(byAdding: .day, value: -2, to: Date())! else { return Streak(length: 0, start: nil, end: nil) }

        var streak: [Date] = [lastWorkoutDay]
        var currentIndex = filtered.count - 1

        // Walk backward through workouts
        while currentIndex > 0 {
            let prevWorkoutDay = filtered[currentIndex - 1]
            let first = prevWorkoutDay
            let last = streak.last!

            guard let totalDays = calendar.dateComponents([.day], from: first, to: last).day else {
                break
            }

            // Create the calendar range and evaluate compliance
            let calendarRange = (0...totalDays).compactMap {
                calendar.date(byAdding: .day, value: $0, to: first)
            }

            let workoutSet = Set([prevWorkoutDay] + streak)
            let isValid = calendarRange.indices.allSatisfy { idx in
                guard idx + 6 < calendarRange.count else { return true }
                let window = calendarRange[idx...idx + 6]
                let restCount = window.filter { !workoutSet.contains($0) }.count
                return restCount <= maxRestDaysPer7
            }

            if isValid {
                streak.insert(prevWorkoutDay, at: 0)
                currentIndex -= 1
            } else {
                break
            }
        }

        return Streak(length: streak.count, start: streak.first, end: streak.last)
    }

    func calculateWeeklyMetrics() -> [WeeklyMetrics] {
        // Step 1: Map each segment to its week + type
        var weeklyData: [Date: (work: TimeInterval, rest: TimeInterval, tonnage: Int, count: Int)] = [:]
        
        for workout in self {
            let workRest = workout.workToRestRatio
            let date = workout.startDate.startOfWeek()
            if weeklyData[date] == nil { weeklyData[date] = (0,0, 0, 0) }
            weeklyData[date]!.rest += workRest.restTime
            weeklyData[date]!.work += workRest.workTime
            
            let tonnage = workout.simpleAndSinisterWeight
            weeklyData[date]!.tonnage += tonnage
            if tonnage > 0 { weeklyData[date]!.count += 1 }
        }
        
        // Step 2: Convert to array of WeeklyWorkRest
        var weeklyArray = weeklyData.map { (week, values) in
            WeeklyMetrics(weekStart: week, work: values.work, rest: values.rest, tonnage: values.count > 0 ? Int(values.tonnage / values.count) : 0)
        }
        .sorted { $0.weekStart < $1.weekStart }
        
        if (weeklyArray.count > 1) {
            for i in 1..<weeklyArray.count {
                let change = weeklyArray[i].ratio - weeklyArray[i-1].ratio
                weeklyArray[i].changeFromLast = change
            }
        }
        return weeklyArray
    }
    
    

}


