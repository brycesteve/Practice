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
            
            }
            header: {
                Text("Stats")
            }
            .headerProminence(.increased)
            ForEach(practice.segments, id: \.name) { segment in
                Section {
                    ForEach(segment.sets.enumerated(), id: \.offset) { _,set in
                        Text(set.description)
                    }
                }
                header: {
                    Text(segment.name)
                }
            }
            
        }
        .navigationTitle(practice.name)
        .navigationSubtitle(practice.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.large)
        
    }
}
