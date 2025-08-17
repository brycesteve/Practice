import SwiftUI
import WatchKit
import Observation

@Observable
final class CrownRotationManager {
    var value: Double = 0 {
        didSet { handleRotation() }
    }
    
    private var isCooldown = false
    private var cooldownDuration: TimeInterval
    var onTrigger: (() -> Void)?
    
    init(cooldownDuration: TimeInterval = 1.0) {
        self.cooldownDuration = cooldownDuration
    }
    
    private func handleRotation() {
        guard !isCooldown else { return }
        isCooldown = true
        WKInterfaceDevice.current().play(.click)
        onTrigger?()
        Task {
            try? await Task.sleep(nanoseconds: UInt64(cooldownDuration * 1_000_000_000))
            await MainActor.run { self.isCooldown = false }
        }
    }
}


// MARK: - ViewModifier
struct DigitalCrownModifier: ViewModifier {
    @State var manager: CrownRotationManager
    var range: ClosedRange<Double>
    var step: Double
    var sensitivity: DigitalCrownRotationalSensitivity

    func body(content: Content) -> some View {
        content
            .focusable(true)
            .digitalCrownRotation(
                $manager.value,
                from: range.lowerBound,
                through: range.upperBound,
                by: step,
                sensitivity: sensitivity,
                isContinuous: true
            )
    }
}

extension View {
    func withDigitalCrown(
        manager: CrownRotationManager,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        sensitivity: DigitalCrownRotationalSensitivity = .medium
    ) -> some View {
        self.modifier(DigitalCrownModifier(manager: manager, range: range, step: step, sensitivity: sensitivity))
    }
}

