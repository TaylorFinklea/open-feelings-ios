import SwiftData
import SwiftUI

/// Hosts the 7-screen thought-record wizard. Driven by an in-memory
/// `ThoughtRecordDraft`. Save behavior depends on whether `existingRecord`
/// is set (edit) or nil (new). Caller is responsible for dismissing the
/// sheet — this view just calls `onComplete` after Save or Cancel.
struct ThoughtRecordFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Initial state. For the "new" flow with no pre-fills, pass
    /// `ThoughtRecordDraft()`. For "examine this thought" from a check-in,
    /// pass `ThoughtRecordDraft.from(log:)`. For the edit flow, pass
    /// `ThoughtRecordDraft.from(record:)` AND set `existingRecord` to that
    /// record.
    @State var draft: ThoughtRecordDraft
    var existingRecord: ThoughtRecord?

    @State private var path: [Step] = []
    @State private var showingCancelAlert = false
    /// Snapshot of the draft at sheet-open time. Compared in `isDirty` to
    /// decide whether Cancel should confirm. Captured in `.task` rather than
    /// `init` so the draft pre-fills (e.g. from `from(log:)`) are included.
    @State private var initialDraft: ThoughtRecordDraft?

    enum Step: Hashable {
        case automaticThought
        case intensityBefore
        case patterns
        case balancedThought
        case intensityAfter
        case confirm
    }

    private var isDirty: Bool {
        guard let initial = initialDraft else { return false }
        return draft != initial
    }

    var body: some View {
        NavigationStack(path: $path) {
            SituationStepView(draft: $draft) {
                path.append(.automaticThought)
            }
            .toolbar { cancelToolbar }
            .navigationDestination(for: Step.self) { step in
                destination(for: step)
                    .toolbar { cancelToolbar }
            }
        }
        .task {
            if initialDraft == nil {
                initialDraft = draft
            }
        }
        .alert("Discard changes?", isPresented: $showingCancelAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your thought record won't be saved.")
        }
    }

    @ToolbarContentBuilder
    private var cancelToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                if isDirty {
                    showingCancelAlert = true
                } else {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        switch step {
        case .automaticThought:
            AutomaticThoughtStepView(draft: $draft) {
                path.append(.intensityBefore)
            }
        case .intensityBefore:
            IntensityBeforeStepView(draft: $draft) {
                path.append(.patterns)
            }
        case .patterns:
            PatternsStepView(draft: $draft) {
                path.append(.balancedThought)
            }
        case .balancedThought:
            BalancedThoughtStepView(draft: $draft) {
                path.append(.intensityAfter)
            }
        case .intensityAfter:
            IntensityAfterStepView(draft: $draft) {
                path.append(.confirm)
            }
        case .confirm:
            ConfirmThoughtRecordView(
                draft: draft,
                onSave: save,
                onEdit: { flowStep in
                    path = pathTo(flowStep)
                }
            )
        }
    }

    /// Compute the NavigationStack path that ends at the given confirm-step
    /// edit target. The user is then on that step with all prior values still
    /// in `draft`; tapping Continue rebuilds the path forward to confirm.
    private func pathTo(_ flowStep: ConfirmThoughtRecordView.FlowStep) -> [Step] {
        switch flowStep {
        case .situation:        return []
        case .automaticThought: return [.automaticThought]
        case .intensityBefore:  return [.automaticThought, .intensityBefore]
        case .patterns:         return [.automaticThought, .intensityBefore, .patterns]
        case .balancedThought:  return [.automaticThought, .intensityBefore, .patterns, .balancedThought]
        case .intensityAfter:   return [.automaticThought, .intensityBefore, .patterns, .balancedThought, .intensityAfter]
        }
    }

    private func save() {
        guard draft.isSaveable else { return }
        if let existing = existingRecord {
            draft.apply(to: existing)
        } else {
            let record = draft.toThoughtRecord()
            context.insert(record)
        }
        try? context.save()
        dismiss()
    }
}
