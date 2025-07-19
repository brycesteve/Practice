//
//  StreakSummaryView.swift
//  Practice
//
//  Created by Steve Bryce on 19/07/2025.
//
import SwiftUI

struct StreakSummaryView: View {
    let currentStreak: Streak
    let longestStreak: Streak

    var body: some View {
        VStack(spacing: 16) {
            SummaryCardView(
                title: "Current Streak",
                icon: "flame.fill",
                value: "\(currentStreak.length) days",
                dateRange: currentStreak.dateRange,
                color: currentStreak.length > 0 ? .orange : .gray
            )

            SummaryCardView(
                title: "Longest Streak",
                icon: "trophy.fill",
                value: "\(longestStreak.length) days",
                dateRange: longestStreak.dateRange,
                color: longestStreak.length > 0 ? .yellow : .gray
            )
        }
        .padding()
    }
}


