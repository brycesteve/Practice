/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The start view.
*/

import SwiftUI
import HealthKit

struct StartView: View {
    @Environment(PracticeManager.self) var practiceManager
    
    @State var navigation = NavigationPath()
    
    @State var practiceStarted = false
    @State var showSettings: Bool = false
    
    
    var body: some View {
        @Bindable var manager = practiceManager
        NavigationStack(path: $navigation) {
            List(practiceManager.availablePractices, id: \.name) { practice in
                 
                Button {
                    practiceManager.selectedPractice = practice
                     
                }
                label: {
                    HStack {
                        practice.image
                            .padding(4)
                            .background {
                                Circle()
                                    .fill(.green)
                            }
                            .foregroundStyle(.background)
                        Spacer().frame(maxWidth: 8)
                        Text(practice.name)
                    }
                }
                
            }
            
            .navigationDestination(isPresented: $manager.running, destination: {
                SessionPagingView()
            })
            
            
            .listStyle(.carousel)
            .navigationBarTitle("Practice")
            .sheet(isPresented: $manager.showingSettingsForPractice, content: {
                AnyView(practiceManager.settingsView!)
            })
            
        }
        .onAppear {
            practiceManager.requestAuthorization()
        }
        
        
    }
}

#Preview {
    StartView()
        .environment(PracticeManager())
}
