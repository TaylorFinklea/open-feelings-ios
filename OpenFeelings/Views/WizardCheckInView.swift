import SwiftUI

struct WizardCheckInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: EmotionSelection?
    /// Cores whose IDs are NOT in this set get rendered at 40% opacity with
    /// a tiny dot below suggested cores. Empty set = no dimming (default).
    var suggestedCoreIDs: Set<String> = []

    @State private var selectedCore: EmotionCore?
    @State private var selectedSecondary: EmotionSecondary?

    /// User explicitly committed at the current drill depth via "Just <name>".
    /// `.core` means stop at core; `.secondary` means stop at secondary. When
    /// set, the deeper-level grid is hidden and a confirmation card shows.
    @State private var stoppedAt: StopLevel?

    private enum StopLevel { case core, secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            stepHeader

            if selectedCore == nil {
                emotionGrid(
                    EmotionTaxonomy.cores,
                    coreID: { $0.id },
                    depth: .core,
                    applyDimming: true
                ) { core in
                    withAnimation(.OF.quick) {
                        selectedCore = core
                        selectedSecondary = nil
                        stoppedAt = nil
                        selection = EmotionSelection(core: core, secondary: nil, specific: nil)
                    }
                }
            } else if let selectedCore, stoppedAt == .core {
                stopConfirmation(name: selectedCore.name) {
                    // Resume drilling — bring back the secondary grid.
                    withAnimation(.OF.quick) { stoppedAt = nil }
                }
            } else if let selectedCore, selectedSecondary == nil {
                VStack(alignment: .leading, spacing: .OF.md) {
                    stopAtLevelRow(label: "Just \(selectedCore.name)") {
                        withAnimation(.OF.quick) {
                            stoppedAt = .core
                            selection = EmotionSelection(core: selectedCore, secondary: nil, specific: nil)
                        }
                    }
                    emotionGrid(
                        selectedCore.secondaries,
                        coreID: { _ in selectedCore.id },
                        depth: .secondary,
                        applyDimming: false
                    ) { secondary in
                        withAnimation(.OF.quick) {
                            selectedSecondary = secondary
                            stoppedAt = nil
                            selection = EmotionSelection(core: selectedCore, secondary: secondary, specific: nil)
                        }
                    }
                }
            } else if let selectedSecondary, stoppedAt == .secondary {
                stopConfirmation(name: selectedSecondary.name) {
                    withAnimation(.OF.quick) { stoppedAt = nil }
                }
            } else if let selectedCore, let selectedSecondary {
                VStack(alignment: .leading, spacing: .OF.md) {
                    stopAtLevelRow(label: "Just \(selectedSecondary.name)") {
                        withAnimation(.OF.quick) {
                            stoppedAt = .secondary
                            selection = EmotionSelection(
                                core: selectedCore,
                                secondary: selectedSecondary,
                                specific: nil
                            )
                        }
                    }
                    emotionGrid(
                        selectedSecondary.specifics,
                        coreID: { _ in selectedCore.id },
                        depth: .specific,
                        applyDimming: false
                    ) { specific in
                        withAnimation(.OF.quick) {
                            selection = EmotionSelection(
                                core: selectedCore,
                                secondary: selectedSecondary,
                                specific: specific
                            )
                        }
                    }
                }
            }

            if selectedCore != nil {
                Button {
                    withAnimation(.OF.quick) {
                        selectedCore = nil
                        selectedSecondary = nil
                        stoppedAt = nil
                        selection = nil
                    }
                } label: {
                    Label("Start over", systemImage: "arrow.counterclockwise")
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(Color.OF.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, .OF.sm)
            }
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentPrompt)
                .font(.OF.headline)
                .foregroundStyle(Color.OF.text)

            if let selection {
                Text(selection.pathTitle)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    private var currentPrompt: String {
        if selectedCore == nil {
            "What is the closest broad feeling?"
        } else if stoppedAt != nil {
            "Tap Continue, or pick more specifically."
        } else if selectedSecondary == nil {
            "Which direction is closest?"
        } else {
            "Which specific word fits best?"
        }
    }

    /// Pill-style row offered above each drill grid: "Just <parent name>".
    /// Visually distinct from the grid tiles so users can spot the stop-here
    /// path even on a quick scan.
    @ViewBuilder
    private func stopAtLevelRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .OF.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.OF.accent.color(for: colorScheme))
                Text(label)
                    .font(.OF.bodyEmphasis)
                    .foregroundStyle(Color.OF.text)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, CGFloat.OF.md)
            .background(
                Color.OF.accent.color(for: colorScheme).opacity(0.10),
                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
                    .stroke(Color.OF.accent.color(for: colorScheme).opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("emotion.\(label)")
    }

    /// Card shown after the user taps "Just <name>". Mirrors the watch's
    /// approach — confirmation that the selection is committed at this depth,
    /// with a path back to drilling further if they change their mind.
    @ViewBuilder
    private func stopConfirmation(name: String, onResume: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            HStack(spacing: .OF.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.OF.accent.color(for: colorScheme))
                Text("Just \(name)")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, CGFloat.OF.md)
            .background(
                Color.OF.accent.color(for: colorScheme).opacity(0.10),
                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
            )

            Button(action: onResume) {
                Label("Pick more specifically", systemImage: "chevron.right")
                    .font(.OF.bodyEmphasis)
                    .foregroundStyle(Color.OF.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func emotionGrid<Item: Identifiable>(
        _ items: [Item],
        coreID: @escaping (Item) -> String,
        depth: EmotionColorPalette.Depth,
        applyDimming: Bool,
        action: @escaping (Item) -> Void
    ) -> some View where Item: EmotionNameProviding {
        // One option per full-width row (Paper "less is more"): a leading
        // core-colored dot + serif name, over the core's own calm wash.
        LazyVStack(spacing: .OF.md) {
            ForEach(items) { item in
                let id = coreID(item)
                let isSuggested = !applyDimming || suggestedCoreIDs.isEmpty || suggestedCoreIDs.contains(id)
                let showsDot = applyDimming && !suggestedCoreIDs.isEmpty && isSuggested
                Button {
                    action(item)
                } label: {
                    HStack(spacing: .OF.sm) {
                        Circle()
                            .fill(EmotionColorPalette.color(coreID: id, depth: depth, scheme: colorScheme))
                            .frame(width: 14, height: 14)

                        Text(item.name)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundStyle(Color.OF.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.horizontal, CGFloat.OF.md)
                    .background(
                        EmotionColorPalette.color(coreID: id, depth: depth, scheme: colorScheme).opacity(0.22),
                        in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
                            .stroke(
                                EmotionColorPalette.color(coreID: id, depth: depth, scheme: colorScheme).opacity(0.45),
                                lineWidth: 1
                            )
                    }
                    .overlay(alignment: .bottom) {
                        if showsDot {
                            Circle()
                                .fill(Color.OF.accent)
                                .frame(width: 5, height: 5)
                                .offset(y: 6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .opacity(isSuggested ? 1 : 0.4)
                .accessibilityIdentifier("emotion.\(item.name)")
            }
        }
    }
}

private protocol EmotionNameProviding {
    var name: String { get }
    var colorHex: String { get }
}

extension EmotionCore: EmotionNameProviding {}
extension EmotionSecondary: EmotionNameProviding {}
extension EmotionSpecific: EmotionNameProviding {}
