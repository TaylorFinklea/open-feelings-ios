import SwiftUI

/// In-app rendering of `docs/PRIVACY.md`. Kept in lockstep with the canonical
/// markdown file so the hosted URL (used in App Store Connect) and the
/// in-app view stay aligned. When you update one, update the other.
struct PrivacyPolicyView: View {
    static let effectiveDate = "2026-05-15"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.lg) {
                Text("Effective date: \(Self.effectiveDate)")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)

                paragraph(
                    "Open Feelings is a free, open-source iOS app for naming "
                  + "and logging emotions. This policy describes what data "
                  + "Open Feelings handles and where that data lives."
                )

                section(
                    title: "What we collect",
                    body: "Open Feelings does not collect, transmit, or sell "
                        + "any data about you. There is no server, no account, "
                        + "no analytics, and no third-party SDK in this app."
                )

                section(
                    title: "Where your data lives",
                    body: "Your check-in entries, intentions, value sorts, and "
                        + "committed actions are stored on your device using "
                        + "SwiftData. If you are signed in to iCloud and have "
                        + "iCloud Drive enabled, the same data is mirrored to "
                        + "your private iCloud database "
                        + "(container iCloud.dev.finklea.openfeelings), which "
                        + "is visible only to you on the Apple IDs you "
                        + "control. Apple's privacy terms govern iCloud sync."
                )

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("Optional integrations (off by default)")
                    bullet("Apple Health. If you enable Apple Health support "
                         + "in Settings, Open Feelings writes each check-in "
                         + "as a State of Mind entry. Open Feelings does not "
                         + "read your Health data. You can revoke access at "
                         + "any time in iOS Settings → Health.")
                    bullet("Daily reminder notifications. If you enable "
                         + "reminders, Open Feelings schedules local "
                         + "notifications on your device. No notification "
                         + "text is sent to any server.")
                    bullet("Apple Watch. If you install the paired Apple "
                         + "Watch app, check-ins captured on the watch are "
                         + "delivered to your phone via WatchConnectivity and "
                         + "stored in the same on-device and private iCloud "
                         + "locations described above.")
                }

                section(
                    title: "Sharing entries",
                    body: "Entries leave the app only when you tap a share "
                        + "affordance. The iOS share sheet hands the entry to "
                        + "whichever app you choose (Apple Journal, Day One, "
                        + "Notes, or any other share-sheet target). The data "
                        + "then becomes subject to that app's privacy policy."
                )

                section(
                    title: "Diagnostics",
                    body: "If you have iOS Settings → Privacy & Security → "
                        + "Analytics & Improvements → \"Share with App "
                        + "Developers\" turned on, Apple may share anonymized "
                        + "crash reports with the developer. These reports do "
                        + "not contain your check-in content. You can opt out "
                        + "in iOS Settings."
                )

                section(
                    title: "Children",
                    body: "Open Feelings is not directed at children under 13. "
                        + "We do not knowingly collect data from anyone."
                )

                section(
                    title: "Changes to this policy",
                    body: "If we change this policy, we'll update the "
                        + "Effective date above and surface the new policy in "
                        + "the app's Settings → Privacy section."
                )

                VStack(alignment: .leading, spacing: .OF.xs) {
                    heading("Open source")
                    paragraph(
                        "Open Feelings is open source. The MIT-licensed Swift "
                      + "source and the adapted CC BY-SA 4.0 emotion taxonomy "
                      + "are documented in ATTRIBUTION.md and DATA-LICENSE.md."
                    )
                    Link("github.com/TaylorFinklea/open-feelings-ios",
                         destination: URL(string: "https://github.com/TaylorFinklea/open-feelings-ios")!)
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.accent)
                }

                VStack(alignment: .leading, spacing: .OF.xs) {
                    heading("Contact")
                    paragraph("Questions or concerns? Open an issue:")
                    Link("github.com/TaylorFinklea/open-feelings-ios/issues",
                         destination: URL(string: "https://github.com/TaylorFinklea/open-feelings-ios/issues")!)
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.accent)
                }
            }
            .padding(.OF.lg)
            .padding(.bottom, CGFloat.OF.xxxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            heading(title)
            paragraph(body)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Color.OF.text)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.OF.body)
            .foregroundStyle(Color.OF.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: .OF.xs) {
            Text("•")
                .foregroundStyle(Color.OF.textMuted)
            Text(text)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack { PrivacyPolicyView() }
}
