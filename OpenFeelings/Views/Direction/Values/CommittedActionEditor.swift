import SwiftUI
import SwiftData

struct CommittedActionEditor: View {
    let rankedTop: [String]
    let customs: [CustomValue]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var valueRef: String = ""
    @State private var whatsHard: String = ""
    @State private var showAllValues = false

    private var allRefs: [String] {
        ValueTaxonomy.all.map(\.id) + customs.map { ValueRef.makeCustomRef($0.id) }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !valueRef.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    TextField("What will you do?", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Value it serves") {
                    Picker("Value", selection: $valueRef) {
                        Text("Pick one").tag("")
                        ForEach(showAllValues ? allRefs : rankedTop, id: \.self) { ref in
                            Text(ValueRef.displayName(for: ref, customs: customs)).tag(ref)
                        }
                    }
                    .pickerStyle(.inline)

                    Button(showAllValues ? "Show ranked only" : "All your values") {
                        showAllValues.toggle()
                    }
                    .font(.subheadline)
                }

                Section("What's hard about it (optional)") {
                    TextField("Optional", text: $whatsHard, axis: .vertical)
                        .lineLimit(1...6)
                }
            }
            .navigationTitle("New committed action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedHard = whatsHard.trimmingCharacters(in: .whitespacesAndNewlines)
                        let action = CommittedAction(
                            title: trimmedTitle,
                            valueRef: valueRef,
                            whatsHard: trimmedHard
                        )
                        context.insert(action)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
