import SwiftUI

/// Soft accent card shown on the Feeling step when the app spots a strong
/// personal pattern in the user's body→secondary history.
struct PersonalizationNudge: View {
    let region: BodyRegion
    let secondaryName: String
    let count: Int
    let total: Int
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            (
                Text("You've picked ")
                    .foregroundStyle(Color.OF.text)
                + Text(secondaryName).bold().foregroundStyle(Color.OF.text)
                + Text(" \(count) of \(total) times for ")
                    .foregroundStyle(Color.OF.text)
                + Text(region.displayName).bold().foregroundStyle(Color.OF.text)
                + Text(". Save as your default?")
                    .foregroundStyle(Color.OF.text)
            )
            .font(.OF.body)
            .multilineTextAlignment(.leading)

            HStack(spacing: .OF.sm) {
                OFButton("Not now", style: .ghost, action: onDismiss)
                OFButton("Save", style: .primary, action: onSave)
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.accentSoft,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }
}
