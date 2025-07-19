//
//  DashboardCard.swift
//  Practice
//
//  Created by Steve Bryce on 06/07/2025.
//
import SwiftUI

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let dateRange: String = ""
    

    var body: some View {
        HStack {
            Image(systemName: icon)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.title2)
                    .bold()
            }

            Spacer()
        }
        
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

#Preview {
    DashboardCard(title: "Test", value: "Value", icon: "calendar", color: .primary)
}

#Preview {
    @Previewable @State var longestStreak = Streak(length: 5, start: Calendar.current.date(from: DateComponents(year:2025, month: 7, day: 17)), end: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 20)))
    SummaryCardView(title: "Longest Streak",
                    icon: "trophy.fill",
                    value: "\(longestStreak.length) days",
                    dateRange: longestStreak.dateRange,
                    color: longestStreak.length > 0 ? .yellow : .gray)
}


struct SummaryCardView: View {
    let title: String
    let icon: String
    let value: String
    let dateRange: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.title2)
                    .bold()
                Text(dateRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}
