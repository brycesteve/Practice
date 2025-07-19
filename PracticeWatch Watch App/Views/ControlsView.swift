/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The workout controls.
*/

import SwiftUI

struct ControlsView: View {
    @Environment(PracticeManager.self) var practiceManager

    var body: some View {
        HStack {
            VStack {
                Button {
                    practiceManager.endWorkout()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.red)
                .buttonStyle(.glass)
                .font(.title2)
                Text("End")
            }
            VStack {
                Button {
                    practiceManager.togglePause()
                } label: {
                    Image(systemName: practiceManager.running ? "pause" : "play")
                }
                .buttonStyle(.glass)
                .tint(.orange)
                .font(.title2)
                Text(practiceManager.running ? "Pause" : "Resume")
            }
        }
    }
}

struct ControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ControlsView().environment(PracticeManager())
    }
}
