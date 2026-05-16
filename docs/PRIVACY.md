# Privacy Policy

**Effective date:** 2026-05-15

Open Feelings is a free, open-source iOS app for naming and logging
emotions. This policy describes what data Open Feelings handles and where
that data lives.

## What we collect

Open Feelings does not collect, transmit, or sell any data about you.
There is no server, no account, no analytics, and no third-party SDK in
this app.

## Where your data lives

Your check-in entries, intentions, value sorts, and committed actions
are stored on your device using SwiftData. If you are signed in to
iCloud and have iCloud Drive enabled, the same data is mirrored to your
*private* iCloud database (container
`iCloud.dev.finklea.openfeelings`), which is visible only to you on the
Apple IDs you control. Apple's privacy terms govern iCloud sync.

## Optional integrations (off by default)

- **Apple Health.** If you enable Apple Health support in Settings,
  Open Feelings writes each check-in as a State of Mind entry. Open
  Feelings does not read your Health data. You can revoke access at any
  time in iOS Settings → Health.
- **Daily reminder notifications.** If you enable reminders, Open
  Feelings schedules local notifications on your device. No notification
  text is sent to any server.
- **Apple Watch.** If you install the paired Apple Watch app, check-ins
  captured on the watch are delivered to your phone via WatchConnectivity
  and stored in the same on-device and private iCloud locations
  described above.

## Sharing entries

Entries leave the app only when you tap a share affordance. The iOS
share sheet hands the entry to whichever app you choose (Apple Journal,
Day One, Notes, or any other share-sheet target). The data then becomes
subject to that app's privacy policy.

## Diagnostics

If you have iOS Settings → Privacy & Security → Analytics & Improvements
→ "Share with App Developers" turned on, Apple may share anonymized
crash reports with the developer. These reports do not contain your
check-in content. You can opt out in iOS Settings.

## Children

Open Feelings is not directed at children under 13. We do not knowingly
collect data from anyone.

## Changes to this policy

If we change this policy, we'll update the **Effective date** above and
surface the new policy in the app's Settings → Privacy section.

## Open source

Open Feelings is open source. The code is available at
<https://github.com/TaylorFinklea/open-feelings-ios>. The MIT-licensed
Swift source and the adapted CC BY-SA 4.0 emotion taxonomy are
documented in `ATTRIBUTION.md` and `DATA-LICENSE.md`.

## Contact

Questions or concerns? Open an issue at
<https://github.com/TaylorFinklea/open-feelings-ios/issues>.
