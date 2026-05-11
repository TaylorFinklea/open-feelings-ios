import SwiftUI

struct NoteEditorSheet: View {
    let log: FeelingLog
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                    .font(.OF.bodyEmphasis)
                    .foregroundStyle(Color.OF.text)
                Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)

                TextEditor(text: $draft)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                    .scrollContentBackground(.hidden)
                    .padding(CGFloat.OF.md)
                    .background(
                        Color.OF.surface,
                        in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous)
                            .stroke(Color.OF.divider, lineWidth: 1)
                    }
                    .frame(minHeight: 140)
                    .accessibilityLabel("Note")
            }
            .padding(CGFloat.OF.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.OF.background)
            .navigationTitle("Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("noteEditor.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(!hasChanges)
                    .accessibilityIdentifier("noteEditor.save")
                }
            }
            .onAppear {
                draft = log.note
            }
        }
    }

    private var hasChanges: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
            != log.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
