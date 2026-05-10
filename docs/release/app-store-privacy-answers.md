# App Store Connect — App Privacy answers

Use these as the source of truth when filling out **App Store Connect → App
Privacy** for Open Feelings. Re-verify any time the app gains a new data
surface (HealthKit reads, network calls, third-party SDKs, etc.).

## TL;DR

**Data collection question: "Does this app collect any data?"** → **No**.

Apple's "App privacy details" form considers data **not collected** when:
- It stays only on the user's device, **or**
- It is transferred only between the user's devices via iCloud end-to-end
  encryption with no developer access, **or**
- It is written to a user-controlled system store (e.g., HealthKit) that the
  developer cannot read back.

Open Feelings meets this bar in v0.1.0:

| Data surface | Where it lives | Developer access | Counts as "collected"? |
|---|---|---|---|
| Check-ins, intentions, reflections, preferences | Local SwiftData store on device | None | No |
| Same data, when iCloud sync is on | User's **private** CloudKit DB | None (Apple's E2E private DB) | No |
| State of Mind samples (Apple Health) | User's HealthKit DB | Write-only — app cannot read back | No |
| Notification scheduling | iOS UserNotifications system | None | No |
| Crash logs | None — no crash reporter SDK is integrated | n/a | No |
| Advertising identifiers | Not requested | n/a | No |

There are no analytics, advertising, attribution, A/B-testing, push, or
crash-reporting SDKs bundled in the app. The only network activity is the
CloudKit traffic Apple performs on the user's behalf when iCloud is signed
in. The developer's servers do not exist — there are none.

## If the form asks any of the following, the answer is "No"

- **Contact Info** — name / email / phone / address / other user contact info
  → No (not requested or stored).
- **Health & Fitness** — heart rate, mood, body, etc. → No (HealthKit writes
  are user-owned and write-only; nothing flows back to the developer).
- **Financial Info** — payment / credit / other → No (not collected).
- **Location** — precise / coarse → No (not requested).
- **Sensitive Info** — race, sexual orientation, religious beliefs,
  disability, political opinion, trade union membership, etc. → No (free-text
  notes may contain anything the user types, but the data never leaves the
  user's device or private iCloud DB; not "collected" by Apple's definition).
- **Contacts** — No.
- **User Content** — emails, photos, videos, gameplay content, customer
  support, or "other" user content → No (notes and check-ins live only on
  device / private iCloud; per Apple's guidance, that does not count).
- **Browsing History / Search History** — No.
- **Identifiers** — User ID, Device ID, Advertising ID, etc. → No.
- **Purchases** — Purchase History → No (no in-app purchases or subscriptions).
- **Usage Data** — Product Interaction, Advertising Data, Other Usage Data →
  No (no analytics SDK, no logging).
- **Diagnostics** — Crash Data, Performance Data, Other Diagnostic Data → No
  (no third-party crash reporter; Apple's own MetricKit data goes to Apple,
  not the developer).
- **Other Data** — No.

## Tracking question

**"Does this app collect data that links the user or device to data
collected from other companies' apps, websites, or offline properties?"**
→ **No**. The app integrates no SDKs that perform tracking. No SKAdNetwork,
no third-party attribution, no advertising network.

## Privacy policy URL

Point App Store Connect → App Information → Privacy Policy URL at the
canonical, user-facing privacy document. Today that lives in `PRIVACY.md` in
the repo. When the app ships, host the rendered version at a public URL
(GitHub Pages from `PRIVACY.md` is the easy default) and paste the URL into
App Store Connect.

## Re-verification triggers

Re-open this document and re-check the answers if the app adds:

- A network request to a non-Apple server.
- A third-party SDK of any kind (analytics, crash, attribution, ads, social).
- A HealthKit *read* call (currently HealthKit is write-only).
- A user account, sign-in, or developer-controlled cloud database.
- An import/export feature that auto-uploads anywhere (current exports are
  share-sheet only — user picks destination, no upload by default).

If any of those land, the "No data collected" answer no longer holds and the
form needs revisiting category by category.
