import SwiftUI
import SwiftData

struct RankStepView: View {
    @Bindable var session: SortSession
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Drag to rank")
                .font(.subheadline)
                .foregroundStyle(Color.OF.textMuted)
                .padding(.horizontal, CGFloat.OF.md)
                .padding(.bottom, CGFloat.OF.sm)

            List {
                ForEach(session.ranked, id: \.self) { ref in
                    HStack {
                        if let position = session.ranked.firstIndex(of: ref) {
                            Text("\(position + 1)")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 24, alignment: .leading)
                                .foregroundStyle(Color.OF.textMuted)
                        }
                        Text(ValueRef.displayName(for: ref, customs: customs))
                            .foregroundStyle(Color.OF.text)
                    }
                }
                .onMove { source, destination in
                    session.reorderRanked(from: source, to: destination)
                }
            }
            .environment(\.editMode, .constant(.active))

            Button("Continue") { session.advancePhase() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(CGFloat.OF.md)
        }
        .navigationTitle("Rank")
    }
}
