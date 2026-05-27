import SwiftUI

/// Step 7 — the confirm screen. Read-only summary of the entire draft with
/// a Save button at the bottom. Save is disabled until `draft.isSaveable`.
/// Per-section pencil buttons jump back to the corresponding step via
/// `onEdit`.
struct ConfirmThoughtRecordView: View {
    let draft: ThoughtRecordDraft
    let onSave: () -> Void
    let onEdit: (FlowStep) -> Void

    enum FlowStep {
        case situation, automaticThought, intensityBefore, patterns,
             balancedThought, intensityAfter
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
                section(title: "Situation",
                        body: draft.situation.isEmpty ? "—" : draft.situation,
                        identifier: "thought-record.confirm.situation",
                        onEdit: { onEdit(.situation) })

                section(title: "Thought",
                        body: draft.automaticThought,
                        identifier: "thought-record.confirm.thought",
                        onEdit: { onEdit(.automaticThought) })

                section(title: "Intensity before",
                        body: intensityLabel(draft.intensityBefore),
                        identifier: "thought-record.confirm.intensity-before",
                        onEdit: { onEdit(.intensityBefore) })

                section(title: "Patterns",
                        body: patternsLabel,
                        identifier: "thought-record.confirm.patterns",
                        onEdit: { onEdit(.patterns) })

                section(title: "Balanced view",
                        body: draft.balancedThought,
                        identifier: "thought-record.confirm.balanced",
                        onEdit: { onEdit(.balancedThought) })

                section(title: "Intensity after",
                        body: intensityLabel(draft.intensityAfter),
                        identifier: "thought-record.confirm.intensity-after",
                        onEdit: { onEdit(.intensityAfter) })

                Button(action: onSave) {
                    Text("Save").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isSaveable)
                .opacity(draft.isSaveable ? 1 : 0.4)
                .padding(.top, CGFloat.OF.md)
                .accessibilityIdentifier("thought-record.save")
            }
            .padding(CGFloat.OF.md)
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var patternsLabel: String {
        draft.patterns.isEmpty
            ? "—"
            : draft.patterns.map(\.displayName).joined(separator: ", ")
    }

    private func intensityLabel(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) / 5"
    }

    @ViewBuilder
    private func section(title: String, body: String, identifier: String,
                         onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            HStack {
                Text(title)
                    .font(.OF.caption.weight(.semibold))
                    .foregroundStyle(Color.OF.textMuted)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.OF.accent)
                }
                .buttonStyle(.plain)
            }
            Text(body)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(identifier)
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
    }
}
