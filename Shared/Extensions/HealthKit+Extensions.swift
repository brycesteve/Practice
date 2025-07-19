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
            .characteristicType(forIdentifier: .dateOfBirth)!
        ]
    }
}

//extension HKWorkout {
//    var completedPracticeMetadata: CompletedPractice? {
//        guard metadata?.keys.contains(where: {$0 == "PracticeMeta"}) ?? false else {
//            return nil
//        }
//        return CompletedPractice(from: metadata!["PracticeMeta"] as! String)
//    }
//}

extension HKWorkout {
    var brandName: String? {
        return metadata?[HKMetadataKeyWorkoutBrandName] as? String
    }
    
    var segments: Dictionary<String, [HKWorkoutActivity]> {
        guard !workoutActivities.isEmpty else { return [:] }
        return Dictionary(grouping: workoutActivities, by: { $0.segemntName ?? "Segment" })
    }
    
    var simpleAndSinisterWeight: Int {
        guard metadata?[HKMetadataKeyWorkoutBrandName] as? String == Practice.SimpleAndSinister.rawValue,
              workoutActivities.count > 0
        else {
            return 0
        }
        let exercises = workoutActivities.compactMap { activity in
            return Exercise.from(activity)
        }.filter {
            if case .swing = $0 { return true }
            if case .getUp = $0 { return true }
            return false
        }
        
        let weight = exercises.reduce(into: 0) {
            switch $1 {
            case let .swing(reps, weight, _),
                let .getUp(reps, weight, _):
                $0 += (weight * reps)
            default:
                return
            }
        }
        return weight
    }
}

extension HKWorkoutActivity {
    var segemntName: String? {
        return metadata?[PracticeSegmentNameMetaDataKey] as? String
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
        let workoutDays = self
            .map { calendar.startOfDay(for: $0.startDate) }
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

        let workoutDays = self
            .map { calendar.startOfDay(for: $0.startDate) }
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


}
