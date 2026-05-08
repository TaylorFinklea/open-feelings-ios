import SwiftUI

/// Final step. Journal text + optional "+ More detail" disclosure that
/// surfaces every chip card the user did NOT promote to its own step.
struct ReflectStep: View {
    @Binding var draft: CheckInDraft
    let promotedSteps: Set<CheckInStepKind>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            journalCard
            MoreDetailDisclosure {
                VStack(spacing: .OF.md) {
                    if !promotedSteps.contains(.sensations) && !draft.bodyRegions.isEmpty {
                        SensationsStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.context) {
                        ContextStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.triggers) {
                        TriggersStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.coping) {
                        CopingStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.mood) {
                        MoodStep(draft: $draft)
                    }
                }
            }
        }
    }

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Journal".uppercased())
                .font(.OF.caption).tracking(1.0).foregroundStyle(Color.OF.textMuted)
            TextEditor(text: $draft.note)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }
                .accessibilityLabel("Journal entry")
            Text("Anything you want to remember about this moment.")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
        }
    }
}
