import SwiftUI

/// In-app rendering of the privacy policy. The canonical text lives in the
/// repo-root `PRIVACY.md` file and is also published on the marketing site
/// (web/src/routes/privacy/+page.svelte → openfeelings.finklea.dev/privacy).
/// When you update the policy, update all three: root `PRIVACY.md`, the
/// Svelte page, and this view's `effectiveDate` + section bodies.
struct PrivacyPolicyView: View {
    /// Mirrors the "Effective" line in repo-root `PRIVACY.md`.
    static let effectiveDate = "May 16, 2026"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.lg) {
                VStack(alignment: .leading, spacing: .OF.xs) {
                    Text("Effective: \(Self.effectiveDate)")
                    Text("Bundle ID: dev.finklea.openfeelings")
                    Text("Developer: Taylor Finklea")
                }
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)

                section(
                    title: "The short version",
                    body: "Open Feelings is a private, on-device tool for "
                        + "naming and logging emotions. Everything you write "
                        + "stays on your device and, if you allow it, in "
                        + "your private iCloud database. We never see it. "
                        + "There is no server we control, no account, no "
                        + "analytics, no ads, and no third-party SDKs."
                )

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("What we don't collect")
                    paragraph("Open Feelings does not:")
                    bullet("Create accounts or require sign-in.")
                    bullet("Send your check-ins, intentions, value sorts, "
                         + "committed actions, notes, intensity values, body "
                         + "regions, mood-scale values, timestamps, or any "
                         + "other content to any server we run. We don't run "
                         + "any servers.")
                    bullet("Use analytics, telemetry, crash reporters, "
                         + "advertising IDs, fingerprinting, or any other "
                         + "tracking.")
                    bullet("Embed third-party SDKs that could collect data.")
                    bullet("Share, sell, rent, or trade any user information.")
                    bullet("Read your contacts, calendars, photos, location, camera, or microphone.")
                    paragraph("Open Feelings never records audio. If you use "
                            + "Siri or keyboard dictation to enter a check-in, "
                            + "your speech is processed by Apple's system "
                            + "services (Siri/dictation), not by Open Feelings "
                            + "— the app receives only the resulting text and "
                            + "still uses no microphone or speech-recognition "
                            + "APIs.")
                }

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("What you enter, the app stores")
                    paragraph("Open Feelings handles only the data you choose to enter:")
                    bullet("Emotion check-ins — the feeling you pick from "
                         + "the wheel or wizard, optional intensity (1–5), "
                         + "optional body regions (curated or custom), "
                         + "optional body sensations, optional context, "
                         + "optional triggers and coping strategies, "
                         + "optional mood-scale values, and any free-text "
                         + "note.")
                    bullet("Daily intentions — the optional one-sentence "
                         + "intention you set each day, and the optional "
                         + "reflection you write afterward.")
                    bullet("Value sorts and committed actions — your "
                         + "bucketing of curated and custom values, your "
                         + "top-ranked list, and any committed actions you "
                         + "define (title, value reference, what's hard, "
                         + "reflection, completion).")
                    bullet("App preferences — check-in flow settings (picker "
                         + "style, body view mode, promoted steps), custom "
                         + "body regions and custom values you've added, "
                         + "reminder time, appearance mode, and Apple Health "
                         + "opt-in.")
                }

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("Where the data lives")
                    bullet("On your device. A local SwiftData store in the "
                         + "app sandbox. The data never leaves the device "
                         + "unless you turn on iCloud sync (below) or "
                         + "explicitly tap a share affordance.")
                    bullet("In your private iCloud database. If you are "
                         + "signed in to iCloud and have iCloud Drive "
                         + "enabled for Open Feelings, Apple's CloudKit "
                         + "framework syncs your data between your own "
                         + "devices using the private database scoped to "
                         + "your Apple ID. The developer of Open Feelings "
                         + "has no access to that database. Apple's privacy "
                         + "policy applies.")
                    bullet("In Apple Health (optional). If you turn on Apple "
                         + "Health support, each saved check-in writes a "
                         + "momentary \"State of Mind\" sample to your "
                         + "Health database. Open Feelings never reads back "
                         + "from Health. You control this in iOS Settings → "
                         + "Privacy & Security → Health → Open Feelings.")
                }

                section(
                    title: "Apple Watch",
                    body: "If you install the paired Apple Watch app, "
                        + "watch-originated check-ins are delivered to your "
                        + "phone via Apple's WatchConnectivity framework and "
                        + "stored in the same on-device and (optional) "
                        + "private iCloud locations described above. The "
                        + "watch app makes no network requests."
                )

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("Optional integrations (off by default)")
                    paragraph("Each integration below is off by default and "
                            + "requires explicit per-permission consent "
                            + "through the system prompts iOS provides. You "
                            + "can disable any of them at any time in Open "
                            + "Feelings → Settings or in iOS Settings.")
                    bullet("Apple Health — State of Mind (write-only). See above.")
                    bullet("Daily reminder notifications. If you turn on "
                         + "daily reminders, iOS schedules a local "
                         + "notification at the time you choose. Nothing is "
                         + "sent to any server.")
                }

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("Sharing you control")
                    paragraph("All sharing is initiated by you:")
                    bullet("History exports. From the History tab you can "
                         + "export check-ins as CSV, JSON, Markdown, or "
                         + "plain text. The file is created in a temporary "
                         + "location and handed to the iOS share sheet; you "
                         + "decide where it goes.")
                    bullet("Therapy summary PDF. From Settings → Sharing → "
                         + "Period summary for therapist, you can generate "
                         + "a PDF over a chosen window and detail level. "
                         + "The PDF stays on the device until you tap share.")
                    bullet("Apple Journal / Day One / Notes handoff. From "
                         + "any individual check-in you can send a Markdown "
                         + "summary to Apple Journal, Day One, Notes, or "
                         + "any other share-sheet target.")
                }

                section(
                    title: "Children",
                    body: "Open Feelings is not directed at children under "
                        + "13 and does not knowingly collect data from "
                        + "anyone — because we do not collect data at all."
                )

                VStack(alignment: .leading, spacing: .OF.sm) {
                    heading("Your rights and how to delete your data")
                    bullet("Delete the app from your device to remove the local database.")
                    bullet("Delete your iCloud copy by going to iOS Settings "
                         + "→ [your name] → iCloud → See All → Open "
                         + "Feelings, or by deleting the app while signed "
                         + "in to iCloud.")
                    bullet("Revoke any optional integration at any time in "
                         + "Open Feelings → Settings or in iOS Settings.")
                    paragraph("Because there is no server we control, there "
                            + "is no account or copy on our side to delete.")
                }

                section(
                    title: "Changes to this policy",
                    body: "If we ever change what the app does in a way "
                        + "that changes this policy, we'll update the "
                        + "Effective date at the top and ship the new "
                        + "policy as part of an app update. The app does "
                        + "not phone home to fetch policy updates "
                        + "dynamically."
                )

                VStack(alignment: .leading, spacing: .OF.xs) {
                    heading("Contact")
                    paragraph("Questions, corrections, or concerns: email "
                            + "taylor.finklea@gmail.com, or file an issue "
                            + "at the project's GitHub repository.")
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
