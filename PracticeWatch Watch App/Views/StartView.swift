/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The start view.
*/

import SwiftUI
import HealthKit
import AppIntents

struct StartView: View {
    @Environment(PracticeManager.self) var practiceManager
    @Environment(WatchAppState.self) var appState
    
    @State var navigation = NavigationPath()
    
    @State var practiceStarted = false
    @State var showSettings: Bool = false
    
    
    var body: some View {
        @Bindable var appState = appState
        @Bindable var manager = practiceManager
        NavigationStack(path: $navigation) {
            List(practiceManager.availablePractices, id: \.name) { practice in
                PracticeRowView(practice: practice) {
                    Task {
                        await startPractice(practice)
                    }
                }
                
            }
            
            .navigationDestination(isPresented: $manager.showMetricsView, destination: {
                SessionPagingView()
            })
            
            //.listStyle(.carousel)
            .navigationBarTitle("Practice")
//            .sheet(isPresented: $manager.showingSettingsForPractice, content: {
//                AnyView(practiceManager.settingsView!)
//            })
            
        }
        .sheet(isPresented: $appState.showReadinessDetail) {
            ReadinessDetailView()
        }
        
    }
    
    func startPractice(_ practice: Practice) async {
        let startIntent = StartPracticeIntent()
        startIntent.practice = PracticeEntity(name: practice.rawValue)
        _ = try? await startIntent.perform()
        _ = try? await startIntent.donate()
    }
}

#Preview{
    StartView()
        .environment(PracticeManager.shared)
}
