//
//  CircularProgressView.swift
//  Practice
//
//  Created by Steve Bryce on 30/05/2025.
//
import SwiftUI
import UIKit
import OSLog

struct CircularProgressView: View {
    @Binding var progress: CGFloat
    @Binding var text: String
    @Binding var rotation: Bool

  var body: some View {
    ZStack {
      // Background for the progress bar
      Circle()
        .stroke(lineWidth: 20)
        .opacity(0.3)
        .foregroundColor(.gray)

      // Foreground or the actual progress bar
      Circle()
        .trim(from: 0.0, to: min(progress, 1.0))
        .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
        .foregroundColor(.green)
        .glassEffect()
        .animation(.linear, value: progress)
        .rotationEffect(rotation ? Angle(degrees: 90.0) : Angle(degrees:270.0))
    }
    .overlay {
        if (!text.isEmpty) {
            Text(text)
                .font(.title)
        }
    }
  }
}

#Preview {
    CircularProgressView(progress: .constant(0.5), text: .constant("Ready!"), rotation: .constant(true))
}
