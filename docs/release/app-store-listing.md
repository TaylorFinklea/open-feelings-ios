# App Store Connect — listing copy (v0.1.0)

Paste these into App Store Connect. Character counts are within Apple's limits
(name ≤30, subtitle ≤30, promotional text ≤170, keywords ≤100, description
≤4000, what's new ≤4000). Drafted 2026-05-29 via a 3-angle judge panel
(privacy-first / calm-wellbeing / depth-tools → judge → synthesis).

> **Do NOT add Face ID / app-lock to the listing.** It's flag-gated OFF in
> v0.1.0 (`FeatureFlags.appLockEnabled = false`); advertising an absent feature
> is an App Review rejection. Re-add to the copy only once the flag ships on.

## Name (13/30)

```
Open Feelings
```

## Subtitle (22/30)

```
Private feelings wheel
```

## Promotional text (145/170)

> Updatable any time without a new review.

```
No accounts, no ads, no analytics, no trackers. Your check-ins live on your device and in your own private iCloud — never on a server we control.
```

## Keywords (92/100)

> Comma-separated, no spaces (maximizes the field). Deliberately excludes words
> already indexed from the name/subtitle (open, feelings, private, wheel).

```
emotion,mood,journal,checkin,wellbeing,calm,mindful,diary,cbt,therapy,offline,stress,tracker
```

## Description (2201/4000)

```
Some days you can name exactly what you feel. Most days you can't. Open Feelings is a quiet, private space to slow down, look inward, and find the right word — one gentle check-in at a time.

At the center is a feelings wheel adapted from the Open Emotion Wheel: start with a broad feeling, then move inward toward something more precise — or stop wherever feels true. Prefer a softer path? A guided three-step check-in walks you there without the full wheel. Selected feelings come with clear, plain-language definitions so naming an emotion also helps you understand it.

A LITTLE EACH DAY
- Pick a feeling from the wheel, or follow the gentle 3-step wizard
- Add only what you want: intensity, a body map, sensations, triggers, coping ideas, a mood scale, or a short note
- Edit any past check-in whenever you want
- Set one daily intention and look back on it later
- Keep a quiet streak going — no pressure, no badges to chase

SEE YOUR PATTERNS
- Insights by week, month, and year: trends, streaks, top feelings, by-day rhythms
- Notice where feelings land in your body and which coping ideas pair with which triggers

GO DEEPER WHEN YOU WANT TO
- Sort what matters to you with a swipe-based values exercise, then commit to small actions
- Work through a thought with a CBT-style thought record — name the thinking pattern, then find a more balanced view
- Create a tidy summary PDF to bring to a therapy session, or export everything as CSV, JSON, Markdown, or text
- Hand a single check-in to Apple Journal, Day One, or Notes

YOURS, AND ONLY YOURS
- No accounts. No ads. No analytics. No trackers. No third-party SDKs.
- Your check-ins live on your device and sync only through your own private iCloud — there's no server we control, and we never see your data
- iCloud sync follows your Apple ID settings and keeps your own devices in step
- Optional Apple Watch check-ins, a daily reminder, and write-only Apple Health "State of Mind"
- Free, with an optional tip jar that simply says thanks — it unlocks nothing

Open Feelings is open source (MIT licensed).

Open Feelings is an educational and reflective tool, not a substitute for professional care, diagnosis, or treatment. If you are in crisis, please contact local emergency services or a crisis line.
```

## What's New (1104/4000)

```
First public release of Open Feelings.

A calm, private place to name what you feel — built local-first, with no accounts, no ads, no analytics, and no tracking.

In this release:
- Emotion check-ins via a feelings wheel adapted from the Open Emotion Wheel, or a gentle guided 3-step wizard
- Plain-language definitions for selected feelings
- Optional detail: intensity, body map, sensations, triggers, coping ideas, mood scale, and notes
- Edit any past check-in
- Insights with weekly, monthly, and yearly trends, streaks, and patterns
- Direction: daily intentions, a swipe-based values sort, and committed actions
- Thoughts: CBT-style thought records to reframe a difficult thought
- Therapy-session summary PDF and full data export (CSV, JSON, Markdown, text)
- Hand a single check-in to Apple Journal, Day One, or Notes
- Private iCloud sync across your own devices, scoped to your Apple ID
- Apple Watch check-ins, a daily reminder, and write-only Apple Health "State of Mind"
- An optional tip jar that unlocks nothing — the app is fully free

Thank you for trying it. Be gentle with yourself.
```

## Other App Store Connect fields (not copy — set these too)

- **Category**: Health & Fitness (primary). Consider Lifestyle as secondary.
- **Privacy Policy URL**: `https://openfeelings.finklea.dev/privacy` (deploy the May 16 copy first).
- **App Privacy / Nutrition Label**: "Data Not Collected" — see `app-store-privacy-answers.md`.
- **Age rating**: complete the questionnaire; the educational/reflective content
  with no objectionable material typically lands at 4+ (confirm via the form).
- **Support URL**: a reachable page (the site root or a GitHub repo link).
- **Verify before submit**: the export-format and Journal/Day One/Notes handoff
  claims match the actual share menu in build 40; remove anything that regressed.
