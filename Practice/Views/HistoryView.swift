//
//  HistoryView.swift
//  Practice
//
//  Created by Steve Bryce on 15/06/2025.
//

import SwiftUI
import OSLog
import HealthKit

struct HistoryView: View {
    @State var selectedDate = Date()
    @State var selectedDatePractices: [HKWorkout] = []
    
    @State var navigationPath = NavigationPath()
    
    @State private var loadingPracticeData: Bool = false
    
    @Environment(HistoryManager.self) private var historyManager
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading) {
                Group {
                    Text("History")
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)
                    
                    
                    CalendarView(selectedDate: $selectedDate)
                    
                    
                    Text("\(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.headline)
                        .padding(.top)
                }.padding(.horizontal)
                List {
                    if (loadingPracticeData) {
                        VStack {
                            ProgressView("Loading Practices",)
                                .progressViewStyle(.automatic)
                                
                        }.frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .listSectionSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    else if (selectedDatePractices.isEmpty){
                        ContentUnavailableView("No practices to view", image: "kettlebell")
                            .listRowSeparator(.hidden)
                            .listSectionSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    else {
                        ForEach(selectedDatePractices, id: \.uuid) { practice in
                            NavigationLink(value: practice) {
                                PracticeSummaryCellView(practice: PracticeSummary(from: practice))
                                    
                            }
                            .listRowSeparator(.hidden)
                            .listSectionSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(.vertical, 8)
                        }
                    }

                }
                .navigationLinkIndicatorVisibility(.hidden)
                .scrollContentBackground(.hidden)
                .listStyle(.grouped)
                .contentMargins(.top, 0, for: .scrollContent)
            }
            .navigationDestination(for: HKWorkout.self) {practice in
                PracticeDetailView(practice:
                    PracticeDetailViewModel(from: practice)
                )
            }
            
            .onChange(of: selectedDate, initial: true) { _, newValue in
                Task {
                    loadingPracticeData = true
                    selectedDatePractices = await historyManager.getCompletedPracticesForDate(newValue)
                    
                    Logger.default.info("Practices for date: \(newValue) \(selectedDatePractices.description)")
                    loadingPracticeData = false
                }
            }
        }
        
        
    }
}

#Preview {
    @Previewable @State var historyManager = HistoryManager.shared
    HistoryView()
        .environment(historyManager)
}

