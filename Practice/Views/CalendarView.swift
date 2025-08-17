//
//  DemoCustomCalendarView20230604.swift
//  iOSDevX
//
//  Created by Xavier on 6/4/23.
//

import SwiftUI
import OSLog
import Foundation

struct CalendarView: View {
    @Binding var selectedDate: Date
    @State var visibleDate: Date = Date()
    @Environment(HistoryManager.self) var historyManager: HistoryManager
    
    private let calendar = Calendar.autoupdatingCurrent

    // Example workout dates (replace with HealthKit data)
    @State private var workoutDates: Set<Date> = []

    var body: some View {
        VStack {
            HStack {
                Text(monthYearString(from: visibleDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            VStack {
                let days = makeDays(for: visibleDate)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 20, maximum: .infinity), spacing: 0), count: 7), alignment: .center, spacing: 10) {
                    let names = Calendar.autoupdatingCurrent.shortWeekdaySymbolsOrdered.enumerated()
                    GridRow {
                        ForEach(names, id: \.offset) { _,day in
                            Text(day)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                
                        }
                    }
                    GridRow {
                        ForEach(0..<7) { _ in
                            
                            Divider()
                        }
                    }
                    
                    
                    ForEach(days, id: \.self) { date in
                        CalendarDayView(
                            date: date,
                            isInMonth: calendar.isDate(date, equalTo: visibleDate, toGranularity: .month),
                            isToday: calendar.isDateInToday(date),
                            hasWorkout: workoutDates.contains(where: { calendar.isDate($0, inSameDayAs: date) }),
                            isSelected: calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
                        )
                        .onTapGesture {
                            if date <= Date() {
                                selectedDate = date
                            }
                        }
                    }
                }
                .padding()
                
                
            }
            .glassEffect(in: .rect(cornerRadius: 16))
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Last", systemImage: "chevron.left") {
                    monthBackward()
                }
                Button("Today") {
                    gotoToday()
                }.foregroundStyle(
                    calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .day) ? Color.green : Color.primary
                )
                
                Button("Next", systemImage: "chevron.right") {
                    monthForward()
                }
                .disabled(calendar.isDate(visibleDate, equalTo: Date(), toGranularity: .month))
            }
            
        }
        
        
    }

    private func makeDays(for date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1)
        else { return [] }

        let days = Date.dates(from: firstWeek.start, to: lastWeek.end - 1)
        retriveWorkouts(for: days)
        return days
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    private func monthForward() {
        withAnimation {
            visibleDate = Calendar.autoupdatingCurrent.date(byAdding: .month, value: 1, to: visibleDate) ?? visibleDate
        }
    }
    
    private func monthBackward() {
        withAnimation {
            visibleDate = Calendar.autoupdatingCurrent.date(byAdding: .month, value: -1, to: visibleDate) ?? visibleDate
        }
    }
    
    private func gotoToday() {
        withAnimation {
            visibleDate = Date()
            selectedDate = Date()
        }
    }
    
    private func retriveWorkouts(for days: [Date]) {
        guard days.count > 1 else { return }
        Task {
            let dates = await historyManager.getPracticedDates(from: days.first!, to: days.last!)
            workoutDates = Set(dates)
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isInMonth: Bool
    let isToday: Bool
    let hasWorkout: Bool
    let isSelected: Bool

    var body: some View {
        
        Text("\(Calendar.current.component(.day, from: date))")
            .fontWeight(isToday ? .heavy : .regular)
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    if hasWorkout {
                        Image(.kettlebellFlat).scaleEffect(2.6)
                            .foregroundColor(.green.opacity(0.8))
                            .offset(y: -6)
                        
                    }
                    if isSelected {
                        Image(systemName: "circle.fill")
                            .resizable()
                            .frame(width: 10, height: 10)
                            .offset(y: 20)
                            .foregroundStyle(.green)
                    }
                }
            )
            .foregroundStyle(date > Date() ? .tertiary : (isInMonth ? .primary : .secondary))
            .foregroundStyle(isToday ? .green : .primary)
            
    
    }
}

extension Date {
    static func dates(from start: Date, to end: Date) -> [Date] {
        Logger.default.info("Start: \(start.description) End: \(end.description)")
        var dates: [Date] = []
        var current = start
        let calendar = Calendar.current

        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return dates
    }
}
#Preview {
    @Previewable @State var selectedDate = Date()
    NavigationStack {
        List {
            CalendarView(selectedDate: $selectedDate)
                .environment(HistoryManager.shared)
        }
    }
}
