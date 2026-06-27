# Privacy Policy

**Effective:** May 16, 2026 ·
**App:** Open Feelings (iOS) ·
**Bundle ID:** `dev.finklea.openfeelings` ·
**Developer:** Taylor Finklea

## The short version

Open Feelings is a private, on-device tool for naming and logging emotions.
Everything you write stays on your device and, if you allow it, in your
*private* iCloud database. We never see it. There is no server we control,
no account, no analytics, no ads, and no third-party SDKs.

## What we don't collect

Open Feelings does not:

- Create accounts or require sign-in.
- Send your check-ins, intentions, value sorts, committed actions, notes,
  intensity values, body regions, mood-scale values, timestamps, or any
  other content to any server we run. We don't run any servers.
- Use analytics, telemetry, crash reporters, advertising IDs,
  fingerprinting, or any other tracking.
- Embed third-party SDKs that could collect data.
- Share, sell, rent, or trade any user information.
- Read your contacts, calendars, photos, location, camera, or microphone.

Open Feelings never records audio. If you use Siri or keyboard dictation
to enter a check-in, your speech is processed by Apple's system services
(Siri/dictation), not by Open Feelings — the app receives only the
resulting text and still uses no microphone or speech-recognition APIs.

## What you enter, the app stores

Open Feelings handles only the data you choose to enter:

- **Emotion check-ins** — the feeling you pick from the wheel or wizard,
  optional intensity (1–5), optional body regions (curated or custom),
  optional body sensations, optional context, optional triggers and coping
  strategies, optional mood-scale values, and any free-text note.
- **Daily intentions** — the optional one-sentence intention you set each
  day, and the optional reflection you write afterward.
- **Value sorts and committed actions** — your bucketing of curated and
  custom values, your top-ranked list, and any committed actions you
  define (title, value reference, what's hard, reflection, completion).
- **App preferences** — check-in flow settings (picker style, body view
  mode, promoted steps), custom body regions and custom values you've
  added, reminder time, appearance mode, and Apple Health opt-in.

## Where the data lives

- **On your device.** A local SwiftData store in the app sandbox. The data
  never leaves the device unless you turn on iCloud sync (below) or
  explicitly tap a share affordance.
- **In your private iCloud database.** If you are signed in to iCloud and
  have iCloud Drive enabled for Open Feelings, Apple's CloudKit framework
  syncs your data between your own devices using the *private* database
  scoped to your Apple ID. The developer of Open Feelings has no access
  to that database. See
  [apple.com/legal/privacy](https://www.apple.com/legal/privacy/) and
  [Apple's iCloud security overview](https://support.apple.com/HT202303).
- **In Apple Health (optional).** If you turn on Apple Health support, each
  saved check-in writes a momentary "State of Mind" sample to your Health
  database. Open Feelings never reads back from Health. You control this
  in iOS Settings → Privacy & Security → Health → Open Feelings.

## Apple Watch

If you install the paired Apple Watch app, watch-originated check-ins are
delivered to your phone via Apple's WatchConnectivity framework and stored
in the same on-device and (optional) private iCloud locations described
above. The watch app makes no network requests.

## Optional integrations (off by default)

Each integration below is off by default and requires explicit per-permission
consent through the system prompts iOS provides. You can disable any of
them at any time in Open Feelings → Settings or in iOS Settings.

- **Apple Health — State of Mind (write-only).** See above.
- **Daily reminder notifications.** If you turn on daily reminders, iOS
  schedules a local notification at the time you choose. Nothing is sent
  to any server.

## Sharing you control

All sharing is initiated by you:

- **History exports.** From the History tab you can export check-ins as
  CSV, JSON, Markdown, or plain text. The file is created in a temporary
  location and handed to the iOS share sheet; you decide where it goes.
- **Therapy summary PDF.** From Settings → Sharing → Period summary for
  therapist, you can generate a PDF over a chosen window and detail
  level. The PDF stays on the device until you tap share.
- **Apple Journal / Day One / Notes handoff.** From any individual
  check-in you can send a Markdown summary to Apple Journal, Day One,
  Notes, or any other share-sheet target.

## Children

Open Feelings is not directed at children under 13 and does not knowingly
collect data from anyone — because we do not collect data at all.

## Your rights and how to delete your data

- **Delete the app** from your device to remove the local database.
- **Delete your iCloud copy** by going to iOS Settings → [your name] →
  iCloud → See All → Open Feelings, or by deleting the app while signed
  in to iCloud.
- **Revoke any optional integration** at any time in Open Feelings →
  Settings or in iOS Settings.

Because there is no server we control, there is no account or copy on our
side to delete.

## Changes to this policy

If we ever change what the app does in a way that changes this policy,
we'll update the **Effective** date at the top and ship the new policy as
part of an app update. The app does not phone home to fetch policy
updates dynamically.

## Contact

Questions, corrections, or concerns:
[taylor.finklea@gmail.com](mailto:taylor.finklea@gmail.com), or file an
issue at the
[project's GitHub repository](https://github.com/TaylorFinklea/open-feelings-ios/issues).
