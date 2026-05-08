import SwiftUI

/// Capsule progress indicator. Renders `total` capsules; the first
/// `currentIndex + 1` are filled with the accent color.
struct StepProgressBar: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= currentIndex
                          ? AnyShapeStyle(Color.OF.accent)
                          : AnyShapeStyle(Color.OF.divider))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
