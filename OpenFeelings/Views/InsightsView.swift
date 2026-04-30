import SwiftUI

struct InsightsView: View {
    @AppStorage("notifyOnInsightsReady") private var notify = false

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
            glyph: "chart.line.uptrend.xyaxis",
            title: "Your patterns, soon.",
            bodyText: "Open Feelings will turn your check-ins into gentle weekly views."
        )
    }

    private var comingUp: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "Coming up")
            previewCard(symbol: "chart.bar.xaxis",     title: "Trends",
                        body: "When and how often each feeling shows up.")
            previewCard(symbol: "rectangle.stack",     title: "Weekly digest",
                        body: "One calm summary every Sunday.")
            previewCard(symbol: "square.and.arrow.up", title: "Therapy bridge",
                        body: "A printable summary you can share with your therapist.")
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

#Preview { NavigationStack { InsightsView() } }
