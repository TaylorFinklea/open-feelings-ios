import SwiftData
import SwiftUI

/// Direction-tab third area, below `ValuesArea`. Renders an empty hero
/// when no records exist, or a list of recent records (newest first) with
/// swipe-to-delete. Tapping a row pushes `ThoughtRecordDetail`. The `+`
/// button in the populated state opens the wizard for a brand-new record.
struct ThoughtRecordsArea: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ThoughtRecord.createdAt, order: .reverse)
    private var records: [ThoughtRecord]

    @State private var showingWizard = false
    @State private var pendingDelete: ThoughtRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("Thought records")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.OF.text)

            if records.isEmpty {
                emptyHero
            } else {
                populated
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingWizard) {
            ThoughtRecordFlowView(draft: ThoughtRecordDraft())
        }
        .alert(item: $pendingDelete) { record in
            Alert(
                title: Text("Delete this record?"),
                message: Text("This can't be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    delete(record)
                },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("Examine a thought that's been stuck.")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Text("Walk through it in six short steps. Notice if it shifts.")
                .foregroundStyle(Color.OF.textMuted)
            Button {
                showingWizard = true
            } label: {
                Text("Start a record")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, CGFloat.OF.xs)
            .accessibilityIdentifier("thought-record.start")
        }
        .padding(CGFloat.OF.md)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }

    @ViewBuilder
    private var populated: some View {
        HStack {
            Text("RECENT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Spacer()
            Button { showingWizard = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("thought-record.start")
        }

        ForEach(records) { record in
            NavigationLink {
                ThoughtRecordDetail(record: record)
            } label: {
                row(for: record)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    pendingDelete = record
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func row(for record: ThoughtRecord) -> some View {
        HStack(alignment: .top, spacing: CGFloat.OF.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.createdAt.formatted(.dateTime.weekday(.abbreviated)
                    .month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Text(record.automaticThought)
                    .font(.body)
                    .foregroundStyle(Color.OF.text)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let delta = record.intensityDelta {
                Text(deltaLabel(delta))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(deltaColor(delta))
            }
        }
        .padding(.vertical, CGFloat.OF.xs)
        .padding(.horizontal, CGFloat.OF.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }

    private func deltaLabel(_ delta: Int) -> String {
        if delta > 0 { return "−\(delta)" }
        if delta < 0 { return "+\(-delta)" }
        return "0"
    }

    private func deltaColor(_ delta: Int) -> OFColor {
        // Positive delta = reframe reduced intensity. Reward the user's
        // effort with accent. Zero/negative blend into the muted text.
        if delta > 0 { return Color.OF.accent }
        return Color.OF.textMuted
    }

    private func delete(_ record: ThoughtRecord) {
        context.delete(record)
        try? context.save()
    }
}
