import SwiftData
import SwiftUI

/// Read-only detail view for a saved `ThoughtRecord`. Toolbar pencil opens
/// the wizard pre-filled (edit flow). Linked-log footer appears only when
/// `linkedLogID` resolves to an existing `FeelingLog`.
struct ThoughtRecordDetail: View {
    let record: ThoughtRecord

    @Environment(\.modelContext) private var context
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]
    @State private var showingEdit = false

    private var linkedLog: FeelingLog? {
        guard let id = record.linkedLogID else { return nil }
        return logs.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
                Text("\u{201C}\(record.automaticThought)\u{201D}")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)

                if !record.situation.isEmpty {
                    labeled(title: "Situation", body: record.situation)
                }

                if !record.patterns.isEmpty {
                    VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                        Text("Patterns")
                            .font(.OF.caption.weight(.semibold))
                            .foregroundStyle(Color.OF.textMuted)
                        FlowingChips(patterns: record.patterns)
                    }
                }

                labeled(title: "Balanced view", body: record.balancedThought)

                intensityShift

                if let linkedLog {
                    linkedLogFooter(linkedLog)
                }

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            .padding(CGFloat.OF.md)
        }
        .navigationTitle("Thought record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ThoughtRecordFlowView(
                draft: ThoughtRecordDraft.from(record: record),
                existingRecord: record
            )
        }
    }

    @ViewBuilder
    private func labeled(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            Text(title)
                .font(.OF.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Text(body)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
        }
    }

    @ViewBuilder
    private var intensityShift: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            Text("Intensity shift")
                .font(.OF.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            HStack(spacing: CGFloat.OF.md) {
                intensityRow(label: "Before", value: record.intensityBefore)
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.OF.textMuted)
                intensityRow(label: "After", value: record.intensityAfter)
            }
        }
    }

    @ViewBuilder
    private func intensityRow(label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { v in
                    Circle()
                        .fill(filledDot(v, value: value)
                              ? AnyShapeStyle(Color.OF.accent)
                              : AnyShapeStyle(Color.OF.divider))
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    private func filledDot(_ value: Int, value selection: Int?) -> Bool {
        guard let selection else { return false }
        return value <= selection
    }

    @ViewBuilder
    private func linkedLogFooter(_ log: FeelingLog) -> some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            Text("From check-in")
                .font(.OF.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
        }
    }
}

/// Simple inline chip row for the read-only detail view. Pattern names wrap
/// across multiple rows via LazyVGrid with adaptive sizing.
private struct FlowingChips: View {
    let patterns: [ThinkingPattern]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: CGFloat.OF.xs)],
                  spacing: CGFloat.OF.xs) {
            ForEach(patterns) { pattern in
                Text(pattern.displayName)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.text)
                    .padding(.horizontal, CGFloat.OF.sm)
                    .padding(.vertical, CGFloat.OF.xs)
                    .background(
                        Color.OF.accent.opacity(0.12),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.OF.accent.opacity(0.45), lineWidth: 1)
                    }
            }
        }
    }
}
