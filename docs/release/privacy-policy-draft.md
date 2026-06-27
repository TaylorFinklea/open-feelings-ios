# Open Feelings — Privacy Policy (DRAFT)

> **STATUS: DRAFT.** Requires human + counsel review before publishing or linking from App Store Connect. The factual claims below describe what the app actually does as of branch `redesign-warm-calm-v1`; verify them against the live build before release.

**Effective date:** _to be filled in at release_
**App:** Open Feelings (iOS)
**Bundle ID:** `dev.finklea.openfeelings`
**Developer:** Taylor Finklea

---

## The short version

Open Feelings is a private, on-device journaling tool for naming and logging emotions. Everything you write stays on your device and (if you allow it) in your own private iCloud database. We never see it. There is no server we control, no account, no analytics, no ads, no third-party SDKs.

---

## What we don't collect

Open Feelings does not:

- Create accounts or require sign-in.
- Send your check-ins, notes, intensity values, timestamps, or any other content to any server we run. We don't run any servers.
- Use analytics, telemetry, crash reporters, advertising IDs, fingerprinting, or any other tracking.
- Embed third-party SDKs that could collect data.
- Share, sell, rent, or trade any user information.
- Read your contacts, calendars, photos, location, or microphone.

Open Feelings never records audio. If you use Siri or keyboard dictation to enter a check-in, your speech is processed by Apple's system services (Siri/dictation), not by Open Feelings — the app receives only the resulting text and still uses no microphone or speech-recognition APIs.

---

## What stays on your device

When you save a check-in, the app stores it in a private SwiftData database scoped to this app. That database lives in the app sandbox on the device and (if you have iCloud Drive enabled for Open Feelings) in the **private** CloudKit database under your own Apple ID. Apple's CloudKit infrastructure transports it; we do not have access to it. Apple's privacy commitments for CloudKit private databases apply. See https://www.apple.com/legal/privacy/ and https://support.apple.com/HT202303 for Apple's terms.

Each check-in includes:

- The emotion you picked (path through the wheel: core / secondary / specific).
- An optional 1–5 intensity value.
- An optional free-text note.
- The local timestamp of the entry.
- A flag indicating whether you also wrote it to Apple Health (see below).

---

## Optional integrations (off by default)

Each integration below is **off by default** and requires explicit per-permission consent through the system prompts iOS provides. You can disable any of them at any time in Open Feelings → Settings or in iOS Settings.

### App lock (Face ID / Touch ID / passcode)

If you turn on the app lock, Open Feelings asks iOS to verify your identity using the standard `LocalAuthentication` framework before showing your data. The biometric template never leaves your device; we don't see it.

### Apple Health — State of Mind (write-only)

If you turn on Apple Health integration, Open Feelings writes each check-in as a momentary "State of Mind" sample to your Health database, mapping the emotion to a valence value and label. The app never reads anything back from Health. You control this in iOS Settings → Privacy & Security → Health → Open Feelings.

### Local reminders

If you turn on daily reminders, Open Feelings asks iOS to schedule a local notification at the time you choose. Notifications are scheduled by the system on your device; nothing is sent to any server.

---

## Export and sharing — your choice

You can export your check-ins as CSV or JSON via the History screen's export menu. The export creates a file in a temporary location on your device and hands it to iOS's standard share sheet so **you** decide where it goes (Files, AirDrop, Mail, Notes, etc.). We don't transmit the export anywhere.

---

## Children

Open Feelings is not directed at children under 13. We do not knowingly collect any information from anyone, including children, because we do not collect information at all.

---

## Your rights and how to delete your data

- **Delete the app** from your device to remove the local database.
- **Delete your iCloud copy** by going to iOS Settings → [your name] → iCloud → See All → Open Feelings, or by deleting the app while signed in to iCloud.
- **Revoke any optional integration** at any time in Open Feelings → Settings or in iOS Settings.

Because there is no server we control, there is no account or copy on our side to delete.

---

## Changes to this policy

If we ever change what the app does in a way that changes this policy, we will update the effective date at the top and ship the new policy as part of an app update. The app does not phone home to fetch policy updates dynamically.

---

## Contact

Questions, corrections, or concerns: **taylor.finklea@gmail.com** _(verify before publishing)_

---

# App Store Connect — Privacy Disclosure Mapping

> Internal reference for filling out the **App Privacy** form in App Store Connect. Sources: app source code on branch `redesign-warm-calm-v1`. Re-verify before submission.

App Store Connect asks, for each data type, whether the app **collects** it. Apple's definition of "collect" is "transmitting data off the device, and/or storing data in a remote location, where it is accessible to you or your third-party partners." Every value on Open Feelings stays in the user's own device or their own private CloudKit; none of it is accessible to us. So:

| Apple data type | Does Open Feelings collect it? | Notes |
|---|---|---|
| Contact Info (name, email, phone, address, other) | **No** | No accounts, no contact form. |
| Health & Fitness | **No** | We *write* State of Mind samples to the user's HealthKit (with permission) but never read or transmit them. |
| Financial Info | **No** | No payments. |
| Location | **No** | No location APIs used. |
| Sensitive Info (e.g. religious beliefs, sexual orientation) | **No** | Emotion picks are stored on-device; not transmitted. |
| Contacts | **No** | No Contacts framework usage. |
| User Content (photos, videos, audio, customer support, gameplay, other) | **No** | Notes / emotion paths stay on-device + private CloudKit. |
| Browsing History | **No** | No web view or browsing tracked. |
| Search History | **No** | No search persisted off-device. |
| Identifiers (User ID, Device ID) | **No** | No analytics, no IDFA. |
| Purchases | **No** | App is free; no IAP. |
| Usage Data (product interactions, advertising data, other) | **No** | No analytics. |
| Diagnostics (crash data, performance data, other) | **No** | No crash reporter or performance SDK. |
| Other Data | **No** | — |

App Store Connect should therefore show **"Data Not Collected"** for this app. Tracking question: select **"No, we don't track."**

**Privacy nutrition labels expected at release:** "Data Not Linked to You" → none. "Data Used to Track You" → none. "Data Not Collected" → all of the above.

---

# Apple Review Notes (DRAFT — for the App Review submission)

When submitting a build that uses HealthKit, Apple Review wants to see:

- A clear statement that Open Feelings only **writes** State of Mind samples and never reads from HealthKit. (Confirmed in `OpenFeelings.entitlements` — `com.apple.developer.healthkit` is true; in `HealthService.swift` the only HealthKit API used is `HKHealthStore.save(_:)`.)
- The Info.plist usage strings: `NSHealthUpdateUsageDescription` (currently set), and `NSHealthShareUsageDescription` (also present — verify if it can be removed since we don't read).
- The user can disable Health sync any time in Settings.

Reviewer test path:

1. Launch app → Today empty state shown.
2. Settings → Apple Health → toggle "Save State of Mind entries" → grant permission.
3. Check In tab → pick a feeling → Save.
4. Open Apple Health → Browse → State of Mind. Confirm a sample for today.
5. Disable the toggle in Settings → confirm subsequent saves do not write to Health.

---

# Open questions for human review

- [ ] Confirm the contact email or replace with a privacy@ alias before publishing.
- [ ] Decide whether to host this policy as a static page (e.g., `openfeelings.app/privacy`) or as a GitHub-rendered Markdown link on the App Store listing. Apple accepts a public URL; whichever is chosen, the link must be reachable from the App Store listing AND from inside the app (Settings → About could surface it).
- [ ] Have a counsel review — particularly the deletion / iCloud-portability claims and the "Children" section if there's any chance the app could be marketed toward minors.
- [ ] Consider whether `NSHealthShareUsageDescription` in `Info.plist` should be removed since the app is write-only (Apple's docs require *Update* but only require *Share* if you actually read).
- [ ] Verify the bundle ID, developer name, and any copyright line at the bottom before publishing.
