import SwiftUI
import SwiftData

struct ConfirmSortView: View {
    let session: SortSession
    /// Called with the freshly-saved `ValueSort` after the user taps
    /// Confirm. The parent surface uses this to dismiss the sort sheet
    /// and present the auto-compare modal. If nil, the view just
    /// dismisses itself on success.
    var onCompleted: ((ValueSort) -> Void)?
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.md) {
            Text("Confirm your values")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.OF.text)
                .padding(.horizontal, CGFloat.OF.md)

            List {
                ForEach(Array(session.ranked.enumerated()), id: \.offset) { pair in
                    HStack {
                        Text("\(pair.offset + 1)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 24, alignment: .leading)
                            .foregroundStyle(Color.OF.textMuted)
                        Text(ValueRef.displayName(for: pair.element, customs: customs))
                            .foregroundStyle(Color.OF.text)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Button("Confirm") {
                if let saved = session.finalize(into: context) {
                    try? context.save()
                    if let onCompleted {
                        onCompleted(saved)
                    } else {
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, CGFloat.OF.md)
            .padding(.bottom, CGFloat.OF.md)
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
    }
}
