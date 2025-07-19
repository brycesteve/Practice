//
//  SinisterSettings.swift
//  Practice
//
//  Created by Steve Bryce on 27/05/2025.
//

import SwiftUI

struct SimpleSinisterSettingsView: View {
    
    let availableWeights: [Int] = [8,16,24,32,40,48]
    
    @AppStorage(Exercise.CodingKeys.squat.rawValue) var squatWeight: Int = 16
    @AppStorage(Exercise.CodingKeys.halo.rawValue) var haloWeight: Int = 16
    
    @AppStorage(Exercise.CodingKeys.swing.rawValue) var swingWeight: Int = 24
    @AppStorage(Exercise.CodingKeys.getUp.rawValue) var getupWeight: Int = 24
    
    @AppStorage(UserDefaults.twoHandedSwingsKey) var twoHandedSwings: Bool = false
    
    @Environment(\.dismiss) var dismiss
    @Environment(PracticeManager.self) var workoutManager
    
    
    
    var body: some View {
        //NavigationStack {
            Form {
                Section {
                    Picker("Squat Weight", selection: $squatWeight) {
                        ForEach(availableWeights, id: \.self) {
                            Text("\($0)kg")
                        }
                    }
                    Picker("Halo Weight", selection: $haloWeight) {
                        ForEach(availableWeights, id: \.self) {
                            Text("\($0)kg")
                        }
                    }
                }
                header: {
                    Text("Warm up")
                }
                
                Section {
                    Toggle("2 handed", isOn: $twoHandedSwings)
                    Picker("Swing Weight", selection: $swingWeight) {
                        ForEach(availableWeights, id: \.self) {
                            Text("\($0)kg")
                        }
                    }
                    Picker("Get-up Weight", selection: $getupWeight) {
                        ForEach(availableWeights, id: \.self) {
                            Text("\($0)kg")
                        }
                    }
                }
                header: {
                    Text("Practice")
                }
            }
            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button(role: .cancel, action: {
//                        dismiss()
//                    }) {
//                        Label("Back", systemImage: "arrow.backward")
//                    }
//                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .none, action: {
                        DispatchQueue.main.async {
                            dismiss()
                            workoutManager.startCountdown()
                        }
                    }) {
                        Label("Start", systemImage: "play")
                            .foregroundStyle(.green)
                            .symbolVariant(.fill)
                    }
                }
           }
            
            .navigationTitle("Settings")
        //}
        .ignoresSafeArea(edges: .bottom)
    }
    
    
}

#Preview {
    SimpleSinisterSettingsView()
}
