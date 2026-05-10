# Privacy Policy

**Effective date:** May 10, 2026
**Last updated:** May 10, 2026

Open Feelings is a personal emotion-logging app. This policy explains, in plain
language, what data the app handles and where it lives. The short answer: the
app collects nothing about you, sends nothing to us, and stores everything you
write in places you control.

## What data the app handles

Open Feelings handles only the data you choose to enter:

- **Emotion check-ins** — the feeling you pick from the wheel or wizard,
  optional intensity, optional body regions, optional context, optional
  triggers and coping strategies, optional mood-scale values, and any free-text
  note you write.
- **Daily intentions** — the optional one-sentence intention you set each day
  and the optional reflection you write afterward.
- **App preferences** — your check-in flow settings (picker style, body view
  mode, promoted steps), reminder time, app-lock toggle, appearance mode, and
  Apple Health opt-in.

That's the entire list. There is no analytics SDK, no advertising SDK, no
crash reporter, no fingerprinting, no telemetry. No third-party SDKs of any
kind are bundled in the app.

## Where the data lives

- **On your device.** Check-ins, intentions, and preferences live in a local
  SwiftData store on the device. They never leave the device unless you turn
  on iCloud sync (below) or you explicitly tap the share affordance to send a
  copy somewhere.
- **In your private iCloud database.** If you are signed in to iCloud, Apple's
  CloudKit framework can sync your check-ins between your own devices using
  the *private* database scoped to your Apple ID. The developer of Open
  Feelings has no access to that database. Apple's privacy policy applies.
- **In Apple Health (optional).** If you turn on the Apple Health integration
  in Settings, each saved check-in writes a "State of Mind" sample to the
  Health app. This is write-only — Open Feelings never reads back from Health.
  The data lives in Health, governed by Apple's HealthKit privacy model.

## What the app does not do

- It does not require an account or sign-in of any kind.
- It does not contact any third-party server. The app makes no network
  requests other than the CloudKit traffic Apple performs on its own when
  iCloud sync is on.
- It does not show ads or track you across apps or websites.
- It does not collect contacts, photos, location, microphone, or camera data.
- It does not send or sell your data to anyone.

## Sharing you control

The app provides a few ways to share data, all initiated by you:

- **History exports.** From the History tab, you can export check-ins as CSV,
  JSON, plain text, Markdown, or Logseq. Each export hands a file to the iOS
  share sheet. Nothing leaves the device until you pick a destination.
- **Therapy summary PDF.** From Settings → Sharing → Period summary for
  therapist, you can generate a PDF over a chosen window and detail level.
  The PDF stays on the device until you tap share.
- **Apple Journal / Day One handoff.** From any individual check-in you can
  send a Markdown summary to Apple Journal, Day One, Notes, or any other app
  via the iOS share sheet.

## Children

The app is not directed to children under 13 and does not knowingly collect
data from children.

## Changes to this policy

If the policy changes, the new version will be published in this file and the
"Last updated" date above will move forward. Material changes will be
described in release notes.

## Contact

Open Feelings is maintained by Taylor Finklea. For privacy questions, file an
issue at the project's GitHub repository or email the address listed in the
App Store contact field.
