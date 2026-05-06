//
//  ErrorState.swift
//  Practice
//
//  Created by Steve Bryce on 02/05/2026.
//


// ErrorState.swift — TrainingShared
// Lightweight observable error surface. Inject into the environment once at
// the app root; any view or manager can post errors without tight coupling.
//
// Usage:
//   @Environment(ErrorState.self) private var errorState
//   errorState.post("Failed to save workout")
//
// The banner auto-dismisses after 4 seconds.

import Foundation
import Observation

@Observable
@MainActor
public final class ErrorState {
    public var currentMessage: String? = nil
    public var isShowing: Bool = false

    private var dismissTask: Task<Void, Never>? = nil

    public init() {}

    public func post(_ message: String) {
        currentMessage = message
        isShowing = true

        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    public func dismiss() {
        isShowing = false
        currentMessage = nil
    }
}