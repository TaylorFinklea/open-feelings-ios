import SwiftUI
import SwiftData

struct BucketStepView: View {
    let session: SortSession
    @Environment(\.modelContext) private var context

    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @State private var showingAddCustom = false
    @State private var newCustomName = ""

    var body: some View {
        VStack(spacing: CGFloat.OF.md) {
            Text("\(session.index + 1) of \(session.deck.count)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.OF.textMuted)

            if let ref = session.currentRef {
                cardView(ref: ref)
                bucketButtons(ref: ref)
            } else {
                advancePrompt
            }

            HStack {
                Button {
                    session.undoLastBucket()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(session.history.isEmpty)
                Spacer()
                Button {
                    newCustomName = ""
                    showingAddCustom = true
                } label: {
                    Label("Add your own value", systemImage: "plus")
                }
            }
            .font(.subheadline)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Sort values")
        .sheet(isPresented: $showingAddCustom) {
            AddCustomValueSheet(name: $newCustomName) { trimmed in
                let custom = CustomValue(name: trimmed)
                context.insert(custom)
                try? context.save()
                session.appendCustom(ValueRef.makeCustomRef(custom.id))
                showingAddCustom = false
            }
        }
    }

    @ViewBuilder
    private func cardView(ref: String) -> some View {
        VStack(spacing: CGFloat.OF.xs) {
            Text(ValueRef.displayName(for: ref, customs: customs))
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.OF.text)
            if !ValueRef.isCustom(ref),
               let def = ValueTaxonomy.definition(id: ref) {
                Text(def.description)
                    .font(.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, CGFloat.OF.xl)
        .padding(.horizontal, CGFloat.OF.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }

    @ViewBuilder
    private func bucketButtons(ref: String) -> some View {
        VStack(spacing: CGFloat.OF.sm) {
            Button { session.bucket(ref, into: .veryImportant) } label: {
                Text("Very important").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button { session.bucket(ref, into: .important) } label: {
                Text("Important").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button { session.bucket(ref, into: .notForMe) } label: {
                Text("Not for me").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(Color.OF.textMuted)
        }
    }

    @ViewBuilder
    private var advancePrompt: some View {
        VStack(spacing: CGFloat.OF.sm) {
            Text("All values bucketed.")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Button("Continue") { session.advancePhase() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, CGFloat.OF.xxl)
    }
}

