//
//  DashboardView.swift
//  Practice
//
//  Created by Steve Bryce on 06/07/2025.
//
import SwiftUI
import HealthKit
import OSLog
import Charts

struct DashboardView: View {
    @State var practices: [HKWorkout] = []
    @Environment(\.scenePhase) var scenePhase
    @Environment(HistoryManager.self) var historyManager
    @Environment(GlobalLoadingState.self) var loadingState
    
    var body: some View {
        NavigationStack {
           List {
              ReadinessCard()
                   .glassEffect(.regular, in: .rect(cornerRadius: 12))
                   .listRowSeparator(.hidden)
                   .listSectionSeparator(.hidden)
                   .listRowInsets(.vertical, 8)
            
               let current = currentStreak()
            let longest = longestStreak()
               
               HStack {
                   VStack(alignment: .leading) {
                       Text("Current Streak")
                           .font(.caption)
                           .foregroundStyle(.secondary)
                       Text("\(current.length) days")
                           .font(.title3.bold())
                   }
                   Spacer()
                   VStack(alignment: .leading) {
                       Text("Longest Streak")
                           .font(.caption)
                           .foregroundStyle(.secondary)
                       Text("\(longest.length) days")
                           .font(.title3.bold())
                   }
                   Spacer()
                   VStack(alignment: .leading) {
                       Text("Last Workout")
                           .font(.caption)
                           .foregroundStyle(.secondary)
                       Text(relativeDate(of: practices.last?.endDate))
                           .font(.title3.bold())
                   }
               }
               .padding()
               .glassEffect(.regular, in: .rect(cornerRadius: 12))
               .listRowSeparator(.hidden)
               .listSectionSeparator(.hidden)
               .listRowInsets(.vertical, 8)
            
               
               //Work/Rest
               WeeklyMetricsView(practices: practices)
               .padding()
               .glassEffect(.regular, in: .rect(cornerRadius: 12))
               .listRowSeparator(.hidden)
               .listSectionSeparator(.hidden)
               .listRowInsets(.vertical, 8)
               
               ProgressCard(currentTonnage: rollingAverageWorkoutMass())
                   .padding()
                   .glassEffect(.regular, in: .rect(cornerRadius: 12))
                   .listRowSeparator(.hidden)
                   .listSectionSeparator(.hidden)
                   .listRowInsets(.vertical, 8)
               VO2MaxTrendCard()
                   .padding()
                   .glassEffect(.regular, in: .rect(cornerRadius: 12))
                   .listRowSeparator(.hidden)
                   .listSectionSeparator(.hidden)
                   .listRowInsets(.vertical, 8)
                
            }
           .scrollContentBackground(.hidden)
           .listStyle(.plain)
           .refreshable {
               await ReadinessManager.shared.refresh()
           }
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
    
    func rollingAverageWorkoutMass() -> Double {
        let relevantPractices = practices.suffix(5)
        guard !relevantPractices.isEmpty else {
            return 0
        }
        
        let mass = relevantPractices.reduce(into: 0) { accum, next in
            accum += next.simpleAndSinisterWeight
        }
        return Double(mass / relevantPractices.count)
    }
    
    func currentStreak() -> Streak {
        return practices.calculateCurrentComplianceWorkoutStreak()
    }
    
    func longestStreak() -> Streak {
        return practices.calculateLongestComplianceWorkoutStreak()
    }

    func relativeDate(of date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = .standalone
        formatter.dateTimeStyle = .named
        return formatter.string(for: date) ?? ""
    }
}

#Preview {
    @Previewable @State var historyManager: HistoryManager = HistoryManager.shared
    NavigationStack {
        DashboardView()
            .environment(historyManager)
            .environment(GlobalLoadingState())
            .environment(ReadinessManager.shared)
    }
}


