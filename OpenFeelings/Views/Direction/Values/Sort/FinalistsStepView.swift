import SwiftUI
import SwiftData

struct FinalistsStepView: View {
    let session: SortSession
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    var body: some View {
        let pool = session.veryImportantPool
        VStack(alignment: .leading, spacing: CGFloat.OF.md) {
            if pool.isEmpty {
                emptyPoolFallback
            } else {
                Text("Pick your finalists")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.OF.text)
                Text("\(session.finalists.count) / \(SortSession.finalistCap)")
                    .font(.subheadline)
                    .foregroundStyle(Color.OF.textMuted)
                chipsGrid(refs: pool)
                Spacer(minLength: CGFloat.OF.xs)
                Button("Continue to ranking") {
                    session.advancePhase()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(session.finalists.isEmpty)
            }
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Finalists")
    }

    @ViewBuilder
    private var emptyPoolFallback: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("No values marked Very important")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Text("Restart the sort and place at least one value in the Very important bucket.")
                .foregroundStyle(Color.OF.textMuted)
            Button("Restart sort") {
                session.restartBucketing()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func chipsGrid(refs: [String]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(refs, id: \.self) { ref in
                chipButton(ref: ref)
            }
        }
    }

    private func chipButton(ref: String) -> some View {
        let selected = session.finalists.contains(ref)
        return Button { session.toggleFinalist(ref) } label: {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark") }
                Text(ValueRef.displayName(for: ref, customs: customs))
                    .lineLimit(1)
            }
            .padding(.horizontal, CGFloat.OF.sm)
            .padding(.vertical, CGFloat.OF.xs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                    .fill(selected ? AnyShapeStyle(Color.OF.accent.opacity(0.18)) : AnyShapeStyle(Color.OF.surface))
            )
            .foregroundStyle(selected ? AnyShapeStyle(Color.OF.accent) : AnyShapeStyle(Color.OF.text))
        }
        .buttonStyle(.plain)
    }
}
