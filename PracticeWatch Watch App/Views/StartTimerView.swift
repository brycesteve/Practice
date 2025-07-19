//
//  StartTimerView.swift
//  Practice
//
//  Created by Steve Bryce on 29/05/2025.
//
import SwiftUI
import OSLog

struct StartTimerView: View {
    @Environment(PracticeManager.self) var practiceManager
    @Environment(\.dismiss) var dismiss
    @State var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State var count: Int = 4
    @State var max: Int = 3
    @State var startProgress: CGFloat = 0
    
    var topRotation: Binding<Bool> {
        Binding {
            count == 4
        }
        set: { _ in
            
        }
    }
    
    var progress: Binding<CGFloat> {
        Binding {
            guard count >= 1 else { return 0 }
            return count < 4 ? CGFloat(count - 1) / CGFloat(max) : startProgress
        }
        set: { _ in
            
        }
        
    }
    var progressText: Binding<String> {
        Binding {
            count == 4 ? "Ready!" : "\(count)"
        }
        set: { _ in
            
        }
    }
    var body: some View {
        @Bindable var manager = practiceManager
        VStack {
            CircularProgressView(progress: progress, text: progressText, rotation: topRotation)
                .progressViewStyle(.circular)
                .controlSize(.extraLarge)
                .font(.title)
                .onReceive(timer) { _ in
                    if count > 1 {
                        //DispatchQueue.main.async {
                            count -= 1
                        //}
                        if count == 3 {
                            AudioManager.shared.play()
                        }
                        if count == 1 {
                            self.timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
                        }
                        
                    }
                    else {
                        //DispatchQueue.main.async {
                            self.timer.upstream.connect().cancel()
                            dismiss()
                        //}
                    }
                }
                
        }
        .onAppear {
            startProgress = 1
            Task {
                //#if !targetEnvironment(simulator)
                AudioManager.shared.prepareCountdown()
                try await Task.sleep(nanoseconds: 600_000_000)
                AudioManager.shared.play()
                //#endif
            }
        }
        
    }
}

#Preview {
    @Previewable @State var practiceManager = PracticeManager()
    StartTimerView()
        .environment(practiceManager)
}
