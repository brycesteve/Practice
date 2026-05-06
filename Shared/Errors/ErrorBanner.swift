//
//  ErrorBanner.swift
//  Practice
//
//  Created by Steve Bryce on 02/05/2026.
//

// ErrorBanner.swift — TrainingShared
// View modifier applied once at the root of each app target.
//
// Usage:
//   ContentView()
//       .errorBanner()
//       .environment(errorState)

import SwiftUI

public struct ErrorBannerModifier: ViewModifier {
    @Environment(ErrorState.self) private var errorState
    
    public func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if errorState.isShowing, let message = errorState.currentMessage {
                ErrorBannerView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { errorState.dismiss() } }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .zIndex(999)
            }
        }
        .animation(.spring(duration: 0.35), value: errorState.isShowing)
    }
}

struct ErrorBannerView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Image(systemName: "xmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

public extension View {
    func errorBanner() -> some View {
        modifier(ErrorBannerModifier())
    }
}
