import SwiftUI

struct IntentionsView: View {
    @AppStorage("notifyOnIntentionsReady") private var notify = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                hero
                comingUp
                notifyToggle
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        OFEmptyState(
            glyph: "leaf",
            title: "Intentions, coming soon.",
            bodyText: "Choose what you'd like to feel — and let your check-ins help you notice."
        )
    }

    private var comingUp: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "Coming up")
            previewCard(symbol: "sun.horizon",
                        title: "Set today's intention",
                        body: "Choose what you'd like to feel today.")
            previewCard(symbol: "calendar",
                        title: "Look back",
                        body: "See how last week's intentions met your real check-ins.")
        }
    }

    private func previewCard(symbol: String, title: String, body: String) -> some View {
        OFCard {
            HStack(alignment: .top, spacing: .OF.md) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.OF.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.OF.headline).foregroundStyle(Color.OF.text)
                    Text(body).font(.OF.body).foregroundStyle(Color.OF.textMuted)
                }
            }
        }
    }

    private var notifyToggle: some View {
        OFButton(notify ? "We'll let you know" : "Notify me when this is ready",
                 style: notify ? .secondary : .primary) {
            notify.toggle()
        }
    }
}

#Preview { NavigationStack { IntentionsView() } }
