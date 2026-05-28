import SwiftUI
import SwiftData

struct CommittedActionDetail: View {
    @Bindable var action: CommittedAction
    let customs: [CustomValue]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteAlert = false

    var body: some View {
        Form {
            Section {
                Text(action.title).font(.title3.weight(.semibold))
                Text("Serves: \(ValueRef.displayName(for: action.valueRef, customs: customs))")
                    .foregroundStyle(Color.OF.textMuted)
            }

            if !action.whatsHard.isEmpty {
                Section("What's hard about it") {
                    Text(action.whatsHard)
                }
            }

            if !action.isDone {
                Section {
                    Button("Mark done") {
                        action.markDone()
                        try? context.save()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Section("Done") {
                    if let completedAt = action.completedAt {
                        Text(completedAt.formatted(date: .long, time: .shortened))
                            .foregroundStyle(Color.OF.textMuted)
                    }
                }

                Section("Reflection") {
                    TextField("How did it go?",
                              text: $action.reflection,
                              axis: .vertical)
                        .lineLimit(2...8)
                        .onChange(of: action.reflection) { _, _ in
                            try? context.save()
                        }
                }
            }

            Section {
                Button("Delete action", role: .destructive) {
                    showingDeleteAlert = true
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("committed-action.delete")
            }
        }
        .navigationTitle("Committed action")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this action?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Self.delete(action, in: context)
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Mutations (static for testability)

    /// Delete the action. No cascade — it references a value, nothing
    /// references it.
    static func delete(_ action: CommittedAction, in context: ModelContext) {
        context.delete(action)
        try? context.save()
    }
}
