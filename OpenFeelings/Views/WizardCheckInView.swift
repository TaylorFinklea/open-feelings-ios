import SwiftUI

struct WizardCheckInView: View {
    @Binding var selection: EmotionSelection?

    @State private var selectedCore: EmotionCore?
    @State private var selectedSecondary: EmotionSecondary?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader

            if selectedCore == nil {
                emotionGrid(EmotionTaxonomy.cores) { core in
                    selectedCore = core
                    selectedSecondary = nil
                    selection = EmotionSelection(core: core, secondary: nil, specific: nil)
                }
            } else if let selectedCore, selectedSecondary == nil {
                emotionGrid(selectedCore.secondaries) { secondary in
                    selectedSecondary = secondary
                    selection = EmotionSelection(core: selectedCore, secondary: secondary, specific: nil)
                }
            } else if let selectedCore, let selectedSecondary {
                emotionGrid(selectedSecondary.specifics) { specific in
                    selection = EmotionSelection(
                        core: selectedCore,
                        secondary: selectedSecondary,
                        specific: specific
                    )
                }
            }

            if selectedCore != nil {
                Button {
                    selectedCore = nil
                    selectedSecondary = nil
                    selection = nil
                } label: {
                    Label("Start over", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentPrompt)
                .font(.title3.weight(.semibold))

            if let selection {
                Text(selection.pathTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        action: @escaping (Item) -> Void
    ) -> some View where Item: EmotionNameProviding {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(items) { item in
                Button {
                    action(item)
                } label: {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private protocol EmotionNameProviding {
    var name: String { get }
}

extension EmotionCore: EmotionNameProviding {}
extension EmotionSecondary: EmotionNameProviding {}
extension EmotionSpecific: EmotionNameProviding {}
