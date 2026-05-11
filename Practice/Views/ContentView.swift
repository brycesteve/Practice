// ContentView.swift — iOS

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            
            ProgressionView()
                .tabItem { Label("Skills", systemImage: "figure.gymnastics") }
            
            KettlebellProgressView()
                .tabItem { Label("Kettlebell", systemImage: "dumbbell.fill") }
            
            PersonalRecordsView()
                .tabItem { Label("Records", systemImage: "trophy.fill") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}


enum Route: Hashable {
    case dashboard
    case recovery
    case conditioning
    case kettleProgress
    case personalRecords
    case bodyStats
    case history
    case settings
}
