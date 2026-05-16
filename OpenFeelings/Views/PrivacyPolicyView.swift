import SwiftUI

/// In-app rendering of the privacy policy. The canonical text lives in the
/// repo-root `PRIVACY.md` file and is also published on the marketing site
/// (web/src/routes/privacy/+page.svelte → openfeelings.finklea.dev/privacy).
/// When you update the policy, update all three: root `PRIVACY.md`, the
/// Svelte page, and this view's `effectiveDate` + section bodies.
struct PrivacyPolicyView: View {
    /// Mirrors the "Effective date" line in repo-root `PRIVACY.md`.
    static let effectiveDate = "May 10, 2026"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.lg) {
                Text("Effective date: \(Self.effectiveDate)")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)

                paragraph(
                    "Open Feelings is a personal emotion-logging app. This "
                  + "policy explains, in plain language, what data the app "
                  + "handles and where it lives. The short answer: the app "
                  + "collects nothing about you, sends nothing to us, and "
                  + "stores everything you write in places you control."
                )

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("What data the app handles")
                    paragraph("Open Feelings handles only the data you choose to enter:")
                    bullet("Emotion check-ins — the feeling you pick from the "
                         + "wheel or wizard, optional intensity, optional body "
                         + "regions, optional context, optional triggers and "
                         + "coping strategies, optional mood-scale values, and "
                         + "any free-text note you write.")
                    bullet("Daily intentions — the optional one-sentence "
                         + "intention you set each day and the optional "
                         + "reflection you write afterward.")
                    bullet("App preferences — your check-in flow settings "
                         + "(picker style, body view mode, promoted steps), "
                         + "reminder time, app-lock toggle, appearance mode, "
                         + "and Apple Health opt-in.")
                    paragraph("That's the entire list. There is no analytics "
                            + "SDK, no advertising SDK, no crash reporter, no "
                            + "fingerprinting, no telemetry. No third-party "
                            + "SDKs of any kind are bundled in the app.")
                }

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("Where the data lives")
                    bullet("On your device. Check-ins, intentions, and "
                         + "preferences live in a local SwiftData store on the "
                         + "device. They never leave the device unless you "
                         + "turn on iCloud sync (below) or you explicitly tap "
                         + "the share affordance to send a copy somewhere.")
                    bullet("In your private iCloud database. If you are "
                         + "signed in to iCloud, Apple's CloudKit framework "
                         + "can sync your check-ins between your own devices "
                         + "using the private database scoped to your Apple "
                         + "ID. The developer of Open Feelings has no access "
                         + "to that database. Apple's privacy policy applies.")
                    bullet("In Apple Health (optional). If you turn on the "
                         + "Apple Health integration in Settings, each saved "
                         + "check-in writes a \"State of Mind\" sample to the "
                         + "Health app. This is write-only — Open Feelings "
                         + "never reads back from Health. The data lives in "
                         + "Health, governed by Apple's HealthKit privacy "
                         + "model.")
                }

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("What the app does not do")
                    bullet("It does not require an account or sign-in of any kind.")
                    bullet("It does not contact any third-party server. The "
                         + "app makes no network requests other than the "
                         + "CloudKit traffic Apple performs on its own when "
                         + "iCloud sync is on.")
                    bullet("It does not show ads or track you across apps or websites.")
                    bullet("It does not collect contacts, photos, location, microphone, or camera data.")
                    bullet("It does not send or sell your data to anyone.")
                }

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("Sharing you control")
                    paragraph("The app provides a few ways to share data, all initiated by you:")
                    bullet("History exports. From the History tab, you can "
                         + "export check-ins as CSV, JSON, plain text, "
                         + "Markdown, or Logseq. Each export hands a file to "
                         + "the iOS share sheet. Nothing leaves the device "
                         + "until you pick a destination.")
                    bullet("Therapy summary PDF. From Settings → Sharing → "
                         + "Period summary for therapist, you can generate a "
                         + "PDF over a chosen window and detail level. The "
                         + "PDF stays on the device until you tap share.")
                    bullet("Apple Journal / Day One handoff. From any "
                         + "individual check-in you can send a Markdown "
                         + "summary to Apple Journal, Day One, Notes, or any "
                         + "other app via the iOS share sheet.")
                }

                section(
                    title: "Children",
                    body: "The app is not directed to children under 13 and "
                        + "does not knowingly collect data from children."
                )

                section(
                    title: "Changes to this policy",
                    body: "If the policy changes, the new version will be "
                        + "published in this file and the \"Last updated\" "
                        + "date above will move forward. Material changes "
                        + "will be described in release notes."
                )

                VStack(alignment: .leading, spacing: .OF.xs) {
                    heading("Contact")
                    paragraph("Open Feelings is maintained by Taylor Finklea. "
                            + "For privacy questions, file an issue at the "
                            + "project's GitHub repository or email the "
                            + "address listed in the App Store contact field.")
                    Link("openfeelings.finklea.dev/privacy",
                         destination: URL(string: "https://openfeelings.finklea.dev/privacy")!)
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
