import SwiftUI

struct WizardCheckInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: EmotionSelection?
    /// Cores whose IDs are NOT in this set get rendered at 40% opacity with
    /// a tiny dot below suggested cores. Empty set = no dimming (default).
    var suggestedCoreIDs: Set<String> = []

    @State private var selectedCore: EmotionCore?
    @State private var selectedSecondary: EmotionSecondary?

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
                        selection = EmotionSelection(core: core, secondary: nil, specific: nil)
                    }
                }
            } else if let selectedCore, selectedSecondary == nil {
                emotionGrid(
                    selectedCore.secondaries,
                    coreID: { _ in selectedCore.id },
                    depth: .secondary,
                    applyDimming: false
                ) { secondary in
                    withAnimation(.OF.quick) {
                        selectedSecondary = secondary
                        selection = EmotionSelection(core: selectedCore, secondary: secondary, specific: nil)
                    }
                }
            } else if let selectedCore, let selectedSecondary {
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

            if selectedCore != nil {
                Button {
                    withAnimation(.OF.quick) {
                        selectedCore = nil
                        selectedSecondary = nil
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
        } else if selectedSecondary == nil {
            "Which direction is closest?"
        } else {
            "Which specific word fits best?"
        }
    }

    private func emotionGrid<Item: Identifiable>(
        _ items: [Item],
        coreID: @escaping (Item) -> String,
        depth: EmotionColorPalette.Depth,
        applyDimming: Bool,
        action: @escaping (Item) -> Void
    ) -> some View where Item: EmotionNameProviding {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: .OF.md)], spacing: .OF.md) {
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
                            .font(.OF.bodyEmphasis)
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
