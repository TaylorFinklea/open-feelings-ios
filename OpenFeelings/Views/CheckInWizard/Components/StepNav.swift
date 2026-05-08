import SwiftUI

/// Bottom navigation buttons for a step. Configures Back / Skip / Continue
/// or Save based on the step's position in the flow.
struct StepNav: View {
    let canGoBack: Bool
    let canSkip: Bool
    let canAdvance: Bool
    let isFinalStep: Bool
    let onBack: () -> Void
    let onSkip: () -> Void
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: .OF.md) {
            if canGoBack {
                OFButton("Back", style: .ghost, action: onBack)
            } else if canSkip {
                OFButton("Skip", style: .ghost, action: onSkip)
            }
            OFButton(isFinalStep ? "Save check-in" : "Continue", style: .primary, action: onAdvance)
                .opacity(canAdvance ? 1 : 0.4)
                .disabled(!canAdvance)
        }
    }
}
