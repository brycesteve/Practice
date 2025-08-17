//
//  PracticeRowView.swift
//  Practice
//
//  Created by Steve Bryce on 26/07/2025.
//


import SwiftUI

struct PracticeRowView: View {
    let practice: Practice
    let onSelect: () -> Void
    //let onSettings: () -> Void
    
    @State var selectedPracticeForSettings: Practice? = nil
    
    var body: some View {
        HStack {
            // Left icon
            practice.image
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .padding(6)
                .background(Circle().fill(Color.green))
                .foregroundStyle(.background)
            
            // Practice name
            Text(practice.watchMenuName)
                .font(.headline)
                //.lineLimit(1)
                .padding(.leading, 4)
            
            Spacer()
            
            // Ellipsis button
            if (practice.settingsView != nil) {
                Button(action: {
                    selectedPracticeForSettings = practice
                }) {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                }
                    .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle()) // Make whole row tappable
        .onTapGesture { onSelect() }
        .padding(.vertical, 6)
        .sheet(item: $selectedPracticeForSettings) { practice in
            AnyView(practice.settingsView!)
        }
    }
}
