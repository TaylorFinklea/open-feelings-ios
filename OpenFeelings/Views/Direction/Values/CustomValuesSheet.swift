import SwiftData
import SwiftUI

/// Manage user-created values: rename or delete. Opened as a sheet from
/// the Values area. Creation still happens inside the value sort — this
/// surface is manage-only.
///
/// Delete is just-delete: past sorts and committed actions that reference
/// a deleted value keep their slot and render "(removed value)" via
/// `ValueRef.displayName`'s existing fallback. No cascade. Rename is safe
/// with no ref updates because references use the UUID, not the name.
struct CustomValuesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomValue.createdAt) private var values: [CustomValue]

    @State private var renaming: CustomValue?
    @State private var renameText = ""
    @State private var pendingDelete: CustomValue?

    var body: some View {
        NavigationStack {
            Group {
                if values.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(values) { value in
                            Button {
                                renameText = value.name
                                renaming = value
                            } label: {
                                Text(value.name)
                                    .foregroundStyle(Color.OF.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = value
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .accessibilityIdentifier("custom-value.row")
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.OF.background, ignoresSafeAreaEdges: .all)
            .navigationTitle("Custom values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename value", isPresented: renameAlertBinding) {
                TextField("Value name", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let value = renaming {
                        Self.rename(value, to: renameText, in: context)
                    }
                    renaming = nil
                }
            }
            .alert(item: $pendingDelete) { value in
                Alert(
                    title: Text("Delete \u{201C}\(value.name)\u{201D}?"),
                    message: Text("Past sorts and actions that used it will show \u{201C}(removed value)\u{201D}."),
                    primaryButton: .destructive(Text("Delete")) {
                        Self.delete(value, in: context)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(get: { renaming != nil },
                set: { if !$0 { renaming = nil } })
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("No custom values yet.")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Text("Add your own during a value sort, then rename or remove them here.")
                .foregroundStyle(Color.OF.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CGFloat.OF.lg)
    }

    // MARK: - Mutations (static for testability)

    /// Trim and persist a new name. No-op if the trimmed name is empty.
    static func rename(_ value: CustomValue, to newName: String, in context: ModelContext) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        value.name = trimmed
        try? context.save()
    }

    /// Delete the value. References elsewhere degrade to "(removed value)".
    static func delete(_ value: CustomValue, in context: ModelContext) {
        context.delete(value)
        try? context.save()
    }
}
