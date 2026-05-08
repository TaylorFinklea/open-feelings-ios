import SwiftData
import SwiftUI

private enum FeelingStepCheckInMode: String, CaseIterable, Identifiable {
    case wizard = "Wizard"
    case wheel  = "Wheel"
    var id: String { rawValue }
}

/// Picker step. Renders the Wizard or Wheel inside a top pill segment.
/// Body→core highlighting comes from `BodyEmotionMap.suggestedCores(...)`
/// (computed in the orchestrator and passed in).
/// Personalization nudge appears when learned dominant secondary exists
/// and no override is in place for the relevant region.
struct FeelingStep: View {
    @Binding var draft: CheckInDraft
    let suggestedCoreIDs: Set<String>
    let nudge: NudgePayload?
    let onSaveOverride: (BodyRegion, String) -> Void
    let onDismissNudge: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("checkInMode") private var modeRawValue = FeelingStepCheckInMode.wizard.rawValue

    /// Inputs needed to render the personalization nudge.
    struct NudgePayload {
        let region: BodyRegion
        let secondaryID: String
        let secondaryName: String
        let count: Int
        let total: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            modeSegmented
            picker
            if let nudge {
                PersonalizationNudge(
                    region: nudge.region,
                    secondaryName: nudge.secondaryName,
                    count: nudge.count,
                    total: nudge.total,
                    onSave: { onSaveOverride(nudge.region, nudge.secondaryID) },
                    onDismiss: onDismissNudge
                )
            }
            if let selection = draft.selection {
                EmotionDefinitionCard(
                    definition: selection.definition,
                    accent: Color.OF.accent.color(for: colorScheme),
                    showsDisclaimer: true
                )
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        switch mode {
        case .wizard:
            WizardCheckInView(selection: $draft.selection, suggestedCoreIDs: suggestedCoreIDs)
        case .wheel:
            // Wheel-mode body→core highlighting is out of scope for v1.
            WheelCheckInView(selection: $draft.selection)
        }
    }

    private var mode: FeelingStepCheckInMode {
        FeelingStepCheckInMode(rawValue: modeRawValue) ?? .wizard
    }

    private var modeSegmented: some View {
        HStack(spacing: 0) {
            ForEach(FeelingStepCheckInMode.allCases) { m in
                Button {
                    withAnimation(.OF.quick) { modeRawValue = m.rawValue }
                } label: {
                    Text(m.rawValue)
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(mode == m ? Color.OF.text : Color.OF.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            Group {
                                if mode == m {
                                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip, style: .continuous)
                                        .fill(Color.OF.surface)
                                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.OF.accentSoft.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip + 4, style: .continuous))
    }
}
