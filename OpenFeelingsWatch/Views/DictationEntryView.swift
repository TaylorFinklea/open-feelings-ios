import SwiftUI

/// "Speak how you feel" capture: a focused TextField that watchOS presents
/// with dictation/scribble on appear (no Speech framework). The parent runs
/// the parse + routing when the user continues.
struct DictationEntryView: View {
    @Binding var text: String
    var onContinue: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("Say how you feel")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Dictate or type", text: $text, axis: .vertical)
                .focused($focused)
                .submitLabel(.done)
                .lineLimit(1...4)
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .navigationTitle("Quick entry")
        .onAppear { focused = true }
    }
}
