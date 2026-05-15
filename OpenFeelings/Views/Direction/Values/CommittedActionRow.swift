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
            Image(systemName: action.isDone ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(action.isDone ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.OF.textMuted))
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.body)
                    .foregroundStyle(action.isDone ? Color.OF.textMuted : Color.OF.text)
                Text(valueLabel)
                    .font(.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            Spacer()
        }
        .padding(.vertical, .OF.xs)
        .opacity(action.isDone ? 0.6 : 1.0)
    }
}
