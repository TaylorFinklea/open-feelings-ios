import SwiftData
import SwiftUI

struct DirectionView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case intentions = "Intentions"
        case values = "Values"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .intentions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                segmentedControl
                // Both sub-areas stay mounted (overlaid) and visibility is
                // toggled, rather than swapped via `if`/`switch`. Swapping
                // would tear down the inactive view's @State — silently
                // discarding an unsaved Intention draft when the user toggles
                // mid-edit. This mirrors the pre-toggle layout where both were
                // always in the tree.
                ZStack(alignment: .top) {
                    IntentionsContent()
                        .opacity(segment == .intentions ? 1 : 0)
                        .allowsHitTesting(segment == .intentions)
                        .accessibilityHidden(segment != .intentions)
                    ValuesArea()
                        .opacity(segment == .values ? 1 : 0)
                        .allowsHitTesting(segment == .values)
                        .accessibilityHidden(segment != .values)
                }
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.top, CGFloat.OF.sm)
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Direction")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Intentions ↔ Values toggle. Mirrors the segmented-control style used by
    /// the Insights period picker and the check-in mode picker (accentSoft
    /// container, white active surface with a soft shadow).
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(Segment.allCases) { seg in
                Button {
                    withAnimation(.OF.quick) { segment = seg }
                } label: {
                    Text(seg.rawValue)
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(segment == seg ? Color.OF.text : Color.OF.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            Group {
                                if segment == seg {
                                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip, style: .continuous)
                                        .fill(Color.OF.surface)
                                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("direction.segment.\(seg.rawValue)")
                .accessibilityLabel(seg.rawValue)
                .accessibilityAddTraits(segment == seg ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .background(Color.OF.accentSoft.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip + 4, style: .continuous))
    }
}

#Preview {
    NavigationStack { DirectionView() }
        .modelContainer(for: [
            FeelingLog.self,
            Intention.self,
            CustomValue.self,
            ValueSort.self,
            CommittedAction.self,
            ThoughtRecord.self
        ], inMemory: true)
}
