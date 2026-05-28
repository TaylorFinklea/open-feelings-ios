import StoreKit
import SwiftUI

/// Settings section: an optional tip jar. Three consumable tiers whose
/// names and prices come from StoreKit (localized). Tips unlock nothing.
/// Mirrors `BackupSection`'s standalone-section structure.
struct SupportSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tipJar = TipJarService()

    var body: some View {
        VStack(spacing: 0) {
            OFSectionHeader(title: "Support")
            VStack(spacing: 0) {
                content
            }
            .background(Color.OF.surface)
            .clipShape(RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
            .padding(.horizontal, CGFloat.OF.lg)
            caption
        }
        .task {
            if tipJar.loadState == .idle { await tipJar.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tipJar.loadState {
        case .idle, .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, CGFloat.OF.lg)
        case .failed:
            Button {
                Task { await tipJar.load() }
            } label: {
                OFListRow.chevron(
                    title: "Couldn't load support options",
                    subtitle: "Tap to retry.",
                    systemImage: "exclamationmark.triangle"
                )
            }
            .buttonStyle(.plain)
        case .loaded:
            ForEach(Array(tipJar.tiers.enumerated()), id: \.element.id) { idx, tier in
                if idx > 0 { divider }
                tipRow(tier)
            }
        }
    }

    private func tipRow(_ tier: Product) -> some View {
        Button {
            Task {
                await tipJar.tip(tier)
                if tipJar.thankedProductID == tier.id {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    try? await Task.sleep(for: .seconds(2))
                    tipJar.clearThanks()
                }
            }
        } label: {
            OFListRow(title: tier.displayName, systemImage: icon(for: tier)) {
                if tipJar.thankedProductID == tier.id {
                    Label("Thank you", systemImage: "checkmark")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.accent)
                } else {
                    Text(tier.displayPrice)
                        .font(.OF.body)
                        .foregroundStyle(Color.OF.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .OF.quick, value: tipJar.thankedProductID)
    }

    /// Tier icons echo the food-scale names. If any symbol fails to
    /// render on the deployment target, swap for "heart".
    private func icon(for tier: Product) -> String {
        if tier.id.hasSuffix("soda") { return "cup.and.saucer" }
        if tier.id.hasSuffix("lunch") { return "fork.knife" }
        if tier.id.hasSuffix("dinner") { return "wineglass" }
        return "heart"
    }

    private var divider: some View {
        Divider()
            .background(Color.OF.divider)
            .padding(.leading, CGFloat.OF.xxxl + .OF.sm)
    }

    private var caption: some View {
        Text("Tips are a thank-you — every feature stays free.")
            .font(.OF.caption)
            .foregroundStyle(Color.OF.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.top, CGFloat.OF.sm)
    }
}
