// ContentView.swift — iOS

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            
            RecoveryView()
                .tabItem { Label("Recovery", systemImage: "heart.text.square.fill") }
            
            ProgressionView()
                .tabItem { Label("Skills", systemImage: "figure.gymnastics") }
            
            KettlebellProgressView()
                .tabItem { Label("Kettlebell", systemImage: "dumbbell.fill") }
            
            PersonalRecordsView()
                .tabItem { Label("Records", systemImage: "trophy.fill") }
            
            BodyStatsView()
                .tabItem { Label("Body", systemImage: "scalemass.fill") }
            
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
