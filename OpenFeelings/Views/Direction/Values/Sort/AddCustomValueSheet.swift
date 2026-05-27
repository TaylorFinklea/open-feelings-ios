import SwiftUI

/// Small modal sheet for adding a user-defined value during the value-sort
/// flow. Used by `SwipeBucketStepView`. Trims input and refuses empty
/// names. Mounts as `.presentationDetents([.medium])`.
struct AddCustomValueSheet: View {
    @Binding var name: String
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Value name", text: $name)
                    .focused($focused)
            }
            .navigationTitle("Add a value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { focused = true }
        }
        .presentationDetents([.medium])
    }
}
