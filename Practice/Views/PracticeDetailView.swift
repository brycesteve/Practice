//
//  PracticeDetail.swift
//  Practice
//
//  Created by Steve Bryce on 22/06/2025.
//
import SwiftUI
import HealthKit

struct PracticeDetailView: View {
    @State var practice: PracticeDetailViewModel
    
    var body: some View {
        List {
            Section {
                DashboardCard(
                    title: "Active Energy",
                    value: "\(practice.totalActiveEnergy.formatted(.number.precision(.fractionLength(0)))) kcal",
                    icon: "flame.fill",
                    color: .orange)
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                .listRowInsets(.vertical, 8)
            //TODO: Duration (Total/Work/Rest)
            //TODO: Heart Rate avg/max
            //TODO: If weight, total weight moved
            }
            header: {
                Text("Stats")
            }
            .headerProminence(.increased)
            ForEach(practice.segments, id: \.name) { segment in
                Section {
                    EmptyView()
                    // TODO: Stats for segment
                }
                header: {
                    Text(segment.name)
                }
            }
            
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .navigationTitle(practice.name)
        .navigationSubtitle(practice.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.large)
        
    }
}
