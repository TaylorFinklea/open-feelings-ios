import SwiftUI

struct NoteEntryView: View {
    @Binding var note: String
    var onContinue: () -> Void

    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("Note (optional)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Dictate or type", text: $note, axis: .vertical)
                .focused($noteFocused)
                .submitLabel(.done)
                .lineLimit(1...4)
            Button("Next", action: onContinue)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear { noteFocused = true }
    }
}
