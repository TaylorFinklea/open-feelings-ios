import SwiftUI

struct CommittedActionRow: View {
    let action: CommittedAction
    let customs: [CustomValue]
    let activeRanked: [String]

    private var valueLabel: String {
        let name = ValueRef.displayName(for: action.valueRef, customs: customs)
        if activeRanked.contains(action.valueRef) {
            return name
        }
        return "\(name) · not in current values"
    }

    var body: some View {
        HStack(spacing: .OF.sm) {
            checkbox
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.body)
                    .strikethrough(action.isDone)
                    .foregroundStyle(action.isDone ? Color.OF.textMuted : Color.OF.text)
                Text(valueLabel)
                    .font(.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            .opacity(action.isDone ? 0.55 : 1.0)
            Spacer()
        }
        .padding(.vertical, .OF.xs)
    }

    /// Rounded checkbox: cool-accent fill + white check when done, hairline
    /// outline when not. The cool fill stays vivid (the row text dims instead),
    /// making the done-state read clearly.
    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(action.isDone ? AnyShapeStyle(Color.OF.accentCool) : AnyShapeStyle(Color.clear))
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(action.isDone ? Color.OF.accentCool : Color.OF.textMuted, lineWidth: 1.5)
            if action.isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.OF.textOnAccent)
            }
        }
        .frame(width: 22, height: 22)
    }
}
