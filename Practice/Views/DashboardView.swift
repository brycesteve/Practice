//
//  DashboardView.swift
//  Practice
//
//  Created by Steve Bryce on 06/07/2025.
//
import SwiftUI
import HealthKit
import OSLog

struct DashboardView: View {
    @State var practices: [HKWorkout] = []
    @Environment(\.scenePhase) var scenePhase
    @Environment(HistoryManager.self) var historyManager
    @Environment(GlobalLoadingState.self) var loadingState
    
    var body: some View {
        NavigationStack {
           List {
                
                let current = currentStreak()
                let longest = longestStreak()
                SummaryCardView(
                    title: "Current Streak",
                    icon: "flame.fill",
                    value: "\(current.length) days",
                    dateRange: current.dateRange,
                    color: current.length > 0 ? .orange : .gray
                )
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                .listRowInsets(.vertical, 8)
                
                SummaryCardView(
                    title: "Longest Streak",
                    icon: "trophy.fill",
                    value: "\(longest.length) days",
                    dateRange: longest.dateRange,
                    color: longest.length > 0 ? .yellow : .gray
                )
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                .listRowInsets(.vertical, 8)
                
                
                DashboardCard(title: "Last Practice", value: relativeDate(of: practices.last?.endDate), icon: "calendar", color: .red)
            
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                .listRowInsets(.vertical, 8)
               
               DashboardCard(
                title: "Simple and Sinister Total",
                value: totalMass().formatted(.practiceMass(width: .wide)), icon: "scalemass.fill",
                color: Color.purple
               )
               .listRowSeparator(.hidden)
               .listSectionSeparator(.hidden)
               .listRowInsets(.vertical, 8)
               
               ProgressGraphView(data: practiceData())
                   .listRowSeparator(.hidden)
                   .listSectionSeparator(.hidden)
                   .listRowInsets(.vertical, 8)
            }
           .scrollContentBackground(.hidden)
           .listStyle(.plain)
            .navigationTitle("Dashboard")
            .task {
                await updatePractices()
            }
            .onChange(of: scenePhase, initial: false) {
                _,newValue in
                if newValue == .active {
                    Task {
                        await updatePractices()
                    }
                }
            }
        }
        
    }
    
    private func updatePractices() async {
        loadingState.dashboardLoading = true
        let startDate = Calendar.autoupdatingCurrent.date(from: DateComponents(year: 2025))!
        practices = await historyManager.getPractices(from: startDate, to: Date())
        loadingState.dashboardLoading = false
    }
    
    func totalMass() -> Measurement<UnitMass> {
        let mass = practices.reduce(into: 0) { accum, next in
            
            accum += next.simpleAndSinisterWeight
        }
        
        return Measurement(value: Double(mass), unit: UnitMass.kilograms)
    }
    
    func practiceData() -> [PracticeVolume] {
        let data = practices.filter{
            $0.simpleAndSinisterWeight > 0
        }.map {
            PracticeVolume(weight: $0.simpleAndSinisterWeight, date: $0.startDate)
        }
        Logger.default.debug("Practice Data: \(data)")
        return data
    }
    
    func currentStreak() -> Streak {
        return practices.calculateCurrentComplianceWorkoutStreak()
    }
    
    func longestStreak() -> Streak {
        return practices.calculateLongestComplianceWorkoutStreak()
    }

    func relativeDate(of date: Date?) -> String {
        guard let date = date else { return "Never" }
        return RelativeDateTimeFormatter().string(for: date) ?? ""
    }
}

#Preview {
    @Previewable @State var historyManager: HistoryManager = .init()
    NavigationStack {
        DashboardView()
            .environment(historyManager)
    }
}


