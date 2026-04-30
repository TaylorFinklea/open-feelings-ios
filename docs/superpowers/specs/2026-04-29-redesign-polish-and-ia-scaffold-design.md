# Open Feelings — Visual + IA Redesign (warm-calm, polish + scaffold)

**Date:** 2026-04-29
**Status:** Draft, awaiting user review
**Scope cycle:** v1
**Predecessor:** N/A (first redesign)

---

## 1. Problem & intent

The current Open Feelings iOS app is functionally complete but isn't App-Store-ready: typography is default SwiftUI, color comes straight from the saturated Flat-UI taxonomy hexes, motion is mostly absent, and the three-tab structure (Check In / History / Settings) leaves no room for several dimensions the user wants to add over time (trends, intentions, body, context, triggers/coping, mood scale, therapy-bridge sharing).

**This cycle's goal**: ship a coherent, beautiful, warm-calm visual system and a five-tab IA that *previews* the new surfaces with first-class empty states. Functionality for each new dimension is queued as its own follow-on spec.

**Weighting confirmed by user**: 60% visual polish · 30% structural room for new dimensions · 10% small check-in improvements.

**Non-goals for this cycle**:
- No SwiftData model changes.
- No service-layer changes.
- No new emotion taxonomy entries.
- No analytics, no third-party SDKs (preserves existing privacy posture).
- No actual functionality behind Insights or Intentions surfaces.
- No actual functionality behind the new check-in placeholder rows.
- No free-form journaling (explicitly de-scoped by user).

---

## 2. Constraints to preserve

| Constraint | Source |
|---|---|
| iOS 26.0 deployment target, SwiftUI, Swift 6.0 | `project.yml`, `AGENTS.md` |
| SwiftData for persistence; per-environment store-mode branching (in-memory tests / on-disk simulator / private CloudKit on device) | `OpenFeelingsApp.swift`, `.docs/ai/decisions.md` |
| Emotion taxonomy structure & string-IDs in `FeelingLog` (logs decoupled from taxonomy churn) | `EmotionTaxonomy.swift`, `FeelingLog.swift`, `AGENTS.md` |
| `WheelViewportTransform` math + `WheelViewportTransformTests` round-trip identity | `EmotionWheelView.swift`, `WheelViewportTransformTests.swift` |
| `HealthService` `@MainActor @Observable`; other services as caseless enums with static async methods | `OpenFeelings/Services/*` |
| MIT for Swift source · CC BY-SA 4.0 for taxonomy text · written-with-attribution clinical references | `LICENSE`, `DATA-LICENSE.md`, `CLINICAL-REFERENCES.md` |
| No third-party SDKs, no analytics, no ads | `README.md`, project ethos |

---

## 3. Aesthetic direction: warm-calm

**Vibe**: parchment-warm neutrals · muted, earthy emotion accents · serif accent for hero / display headings · system sans for body · generous whitespace · gentle ease-in-out motion · iOS 26 Liquid Glass on tab bar and modal backdrops.

**Reference points** (for vibe only — no asset reuse):
- Typography rhythm: New York serif paired with SF Pro / SF Compact text.
- Color sensibility: Reflectly's warm gradient surfaces, Stoic's restrained palette, Dieter Rams "as little design as possible" but warmer.
- Motion: How We Feel's gentle reveal animations.

**What this is NOT**: bouncy/spring-y illustration aesthetic, Flat-UI saturation, monochrome iA-Writer-quiet, or therapy-clinical sterile.

---

## 4. Information architecture

### 4.1 Tab structure

```
┌──────────────────────────────────────────────────────────────┐
│ ╭──────╮  ╭──────╮  ╭──────╮   ╭──────╮   ╭──────╮          │
│ │ Today│  │Check │  │Insi- │   │Inten-│   │Set-  │  ← 5 tabs │
│ │      │  │  In  │  │ ghts │   │tions │   │tings │          │
│ ╰──────╯  ╰──────╯  ╰──────╯   ╰──────╯   ╰──────╯          │
└──────────────────────────────────────────────────────────────┘
```

**Default tab**: **Today**. Reasoning: an emotion-logging app's "home" should be a calm dashboard, not the action-tab. The action lives one tap away in **Check In**, which is also accessible by a primary CTA on Today's empty state. This inverts the current design (Check In as default), which makes the app feel demanding before any data exists.

**Tab order** (left to right): `Today · Check In · Insights · Intentions · Settings`.

**History** is no longer a top-level tab. It moves to a sub-route of Today (`See all history` link / `NavigationLink`). The list itself gets visual polish but the same data and export behavior.

**Wrapping**: the entire tab bar continues to live inside `LockGateView` so the unlock gate is preserved.

### 4.2 Per-surface intent

| Surface | This-cycle deliverable | Functional in this cycle? |
|---|---|---|
| **Today** | Dashboard: greeting, today's logs, intention-of-the-day stub, mini-trend strip, "See all history" link, empty state | Yes — fully functional except trend strip & intention stub which are placeholders (read existing data only) |
| **Check In** | Re-skin of Wizard + Wheel; placeholder rows for Body / Context / Triggers/Coping / Mood-scale | Yes — same save behavior, just polished + placeholder rows |
| **Insights** | Empty-state-only shell with three preview cards (Trends, Weekly Digest, Therapy-bridge) | No — empty state only |
| **Intentions** | Empty-state-only shell with two preview cards (Set today's, Look back) | No — empty state only |
| **Settings** | Re-skinned form; existing controls preserved | Yes — same controls, polished |

---

## 5. Design tokens (`OpenFeelings/Design/DesignTokens.swift`)

### 5.1 Color (semantic)

All values are first-pass and **must be verified for WCAG AA contrast** during implementation. The pairs to verify (in both light and dark):

1. `text` on `background`
2. `text` on `surface`
3. `textMuted` on `background`
4. `textMuted` on `surface`
5. `textOnAccent` on `accent`
6. `accent` on `accentSoft` (button outline / text variants)
7. Each per-core emotion accent on `surface` (label legibility on the wheel)

Where a value fails AA, adjust by ±5% lightness and re-check.

**Neutrals — warm-calm**

| Token | Light | Dark | Notes |
|---|---|---|---|
| `background` | `#FAF6F0` | `#1B1A18` | Warm parchment / warm near-black |
| `surface` | `#FFFFFF` | `#2A2724` | Cards, settings rows |
| `surfaceElevated` | `#FFFFFF` + shadow | `#34302C` | Sheets, modals |
| `text` | `#2B2520` | `#F0EAE0` | Primary text |
| `textMuted` | `#6B6259` | `#A89E92` | Secondary text, captions |
| `textOnAccent` | `#FFFFFF` | `#FFFFFF` | Text on accent fills |
| `divider` | `#E8DFD3` | `#3F3A35` | 1pt rules, separators |
| `accent` | `#C97A4F` | `#D8916A` | Warm terracotta primary |
| `accentSoft` | `#EFD5C2` | `#5C3F2E` | Hover/pressed/selected fills |

**Per-core emotion accents — warm-calm rebalance**

The current taxonomy hexes (`F4D03F`, `3498DB`, `EC7063`, `AF7AC5`, `58D68D`) are saturated Flat-UI. The redesign re-balances them into a unified, lower-saturation, warmer family. The taxonomy file's `colorHex` values are *not modified*; instead, the design system maps each core ID to a redesigned color via a function in `DesignTokens.swift`:

```swift
extension EmotionCore {
    var redesignedAccent: (light: Color, dark: Color) { … }
}
```

| Core | Current (saturated) | Light (warm-calm) | Dark (warm-calm) |
|---|---|---|---|
| Happy   | `#F4D03F` amber | `#D9A43A` honey-amber | `#E5BC68` |
| Sad     | `#3498DB` cobalt | `#6F8FA8` dusty slate-blue | `#93AABF` |
| Angry   | `#EC7063` red-coral | `#C46A55` terracotta | `#D58B79` |
| Fearful | `#AF7AC5` purple | `#A07FB1` dusty mauve | `#B89CC4` |
| Disgusted | `#58D68D` neon green | `#7AA88A` sage | `#99BBA5` |

Per-core *secondary* and *specific* shades derive from the core: `secondary = mix(core, surface, 0.45)`, `specific = mix(core, surface, 0.78)`. Implementation must match the existing visual ratio — outer ring darkest, inner ring lightest — but at the new lower-saturation base.

**Critical**: the wheel rendering must accept its colors from the design system, not from raw `EmotionCore.colorHex`. This is a one-line change in the layout helper.

### 5.2 Typography

Two-family stack:

- **Display / Title**: New York (system serif, available on iOS 26 via `.serif` design token). Used for: `display`, `title`, hero greetings, screen titles where warmth matters.
- **Body / UI**: SF Pro Text. Used for: everything else.
- **Numeric / Mono**: SF Mono. Used for: timestamps, intensity values, data captions.

**Type scale** (all use Dynamic Type via `.system(size:weight:design:)` and scale with the user's preferred text size):

| Role | Base size | Weight | Design | Usage |
|---|---|---|---|---|
| `display` | 34pt | regular | serif | "How are you feeling?" hero |
| `title` | 28pt | regular | serif | Tab screen titles |
| `headline` | 20pt | semibold | default | Card headings, section titles |
| `body` | 17pt | regular | default | Primary body text |
| `bodyEmphasis` | 17pt | semibold | default | Emphasized body |
| `caption` | 13pt | regular | default | Metadata, hints |
| `mono` | 15pt | regular | monospaced | Timestamps, intensity values |

All roles are exposed via a `Font.OF.display`, `Font.OF.title`, etc. extension so views call `.font(.OF.display)`.

### 5.3 Spacing

Linear scale (in pt):

| Token | Value | Use |
|---|---|---|
| `xs` | 4 | Inside chips, tight stacks |
| `sm` | 8 | Inside cards, between adjacent labels |
| `md` | 12 | Default in-card vertical rhythm |
| `lg` | 16 | Page horizontal padding, between cards |
| `xl` | 24 | Between major sections |
| `2xl` | 32 | Hero margins |
| `3xl` | 48 | Above tab bar / safe-area buffers |

### 5.4 Radius

| Token | Value | Use |
|---|---|---|
| `chip` | 6 | Pills, segmented control thumb |
| `card` | 12 | `OFCard`, list rows |
| `sheet` | 20 | Modal sheets, hero containers |
| `wheel` | full circle | Wheel container |

### 5.5 Motion

Three named animations, used consistently:

| Token | Curve | Duration | Use |
|---|---|---|---|
| `quick` | `.easeInOut(duration: 0.18)` | 180ms | Toggle states, segmented switch |
| `gentle` | `.easeInOut(duration: 0.32)` | 320ms | Card slide-in, sheet present, screen content fade-in |
| `settle` | `.spring(response: 0.48, dampingFraction: 0.85)` | ~480ms | Selection confirmation card landing, wheel reset |

**Reduce Motion**: when `accessibilityReduceMotion` is true, all three become `.linear(duration: 0)` (i.e., instant).

### 5.6 Liquid Glass (`OpenFeelings/Design/LiquidGlass.swift`)

iOS 26 Liquid Glass material is applied to:

- The tab bar background (system default in iOS 26 already does this; verify and don't fight it).
- Modal sheet backdrops (using `.presentationBackground(.glass)` or the equivalent iOS 26 API).
- The selection confirmation card on Check In (subtle glass over the wheel below).

Liquid Glass is *not* applied to:
- Cards on Today / Settings — those use solid `surface` for legibility.
- The wheel itself.

---

## 6. Component library (`OpenFeelings/Design/Components/`)

Each component is a thin SwiftUI struct that consumes tokens. All previews go in the same file. Examples are illustrative; final API may evolve during implementation.

### 6.1 `OFCard`

```swift
struct OFCard<Content: View>: View {
    var padding: CGFloat = .OF.lg
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(.OF.surface, in: .rect(cornerRadius: .OF.card))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}
```

### 6.2 `OFListRow`

Used for settings rows and "See all history" — leading icon, title, optional subtitle, trailing accessory (chevron / toggle / value text).

### 6.3 `OFEmptyState`

First-class component because three surfaces need it (Today, Insights, Intentions) plus History when empty. Layout: top-aligned glyph, serif headline, body copy, optional primary CTA.

```swift
OFEmptyState(
    glyph: "leaf.circle",
    title: "Today is open.",
    body: "Tap below to name how you're feeling right now.",
    primaryAction: .init(label: "Start a check-in") { … }
)
```

### 6.4 `OFSectionHeader`

Small uppercase caption + optional inline trailing action. Used in Settings sections and Today sub-sections.

### 6.5 `OFButton`

Variants:

| Variant | Visual |
|---|---|
| `.primary` | accent fill, `textOnAccent`, full width by default |
| `.secondary` | accentSoft fill, accent text |
| `.ghost` | transparent fill, accent text, no border |
| `.destructive` | red-tint fill, white text |

All variants use `quick` motion on press.

### 6.6 `OFTabBar`

**Default plan**: use `TabView` and customize via `UITabBarAppearance` + iOS 26 Liquid Glass defaults. Only build a custom `OFTabBar` if appearance APIs don't deliver the warm-calm look — *fall-through, not first choice*.

---

## 7. Surface specifications

### 7.1 Today

**Purpose**: calm dashboard; default landing surface after unlock.

**Populated state — layout** (top to bottom):

```
┌─────────────────────────────────────────┐
│  Tuesday, April 28           ◌◌◌        │  ← caption + faint trend dots
│                                          │
│  Good morning, Taylor.                   │  ← display (serif)
│                                          │
│  ╭──── Today's intention ────────────╮  │  ← OFCard, placeholder this cycle
│  │  · ·                              │  │
│  │  Coming soon — set what you'd     │  │
│  │  like to feel today.              │  │
│  ╰──────────────────────────────────╯  │
│                                          │
│  ── 2 check-ins today ─────────────────  │  ← OFSectionHeader
│                                          │
│  ╭──────────────────────────────────╮   │
│  │  Peaceful · Thankful             │   │
│  │  ●●●○○  · 2:14 pm  · synced ✓   │   │
│  │  "felt grateful for the walk"    │   │
│  ╰──────────────────────────────────╯   │
│                                          │
│  ╭──────────────────────────────────╮   │
│  │  Anxious · Worried               │   │
│  │  ●●●●○  · 9:02 am                │   │
│  ╰──────────────────────────────────╯   │
│                                          │
│  ── This week ─────────────────────────  │
│  Mostly Calm · 14 check-ins              │  ← mini-trend strip placeholder
│  [tiny week sparkline]                   │
│                                          │
│  → See all history                        │  ← OFListRow link
└─────────────────────────────────────────┘
```

**Empty state** (no logs today):

```
┌─────────────────────────────────────────┐
│  Tuesday, April 28                      │
│                                          │
│  Good morning, Taylor.                   │
│                                          │
│           ╭────────────╮                 │
│           │  ⚙ leaf     │                │  ← OFEmptyState glyph
│           ╰────────────╯                 │
│                                          │
│           Today is open.                 │  ← serif title
│           Tap below to name              │
│           how you're feeling.            │
│                                          │
│       [  Start a check-in   ]            │  ← OFButton.primary
└─────────────────────────────────────────┘
```

**Acceptance criteria**:
- Today is the first tab the user sees post-unlock (and on cold launch).
- Greeting uses `display` (serif) and varies by hour: "Good morning" (<12), "Good afternoon" (12–17), "Good evening" (17–24).
- Today's logs render as `OFCard`s with: emotion path, intensity dots (filled out of 5), timestamp in `mono`, optional sync status, optional note (truncated to 2 lines).
- "Today's intention" card is *visible* but reads "Coming soon — set what you'd like to feel today." It is *not interactive* this cycle.
- "This week" mini-trend strip computes the user's most-frequent core emotion and total log count over the trailing 7 days from existing data. Sparkline is placeholder visual; real sparkline lands in Insights spec.
- "See all history" pushes the (re-skinned) `HistoryView` onto Today's `NavigationStack`. History is no longer a top-level tab.
- Empty state shows when there are zero logs *today* (not zero logs total).

### 7.2 Check In

**Purpose**: the core action. Re-skin only; placeholders for queued dimensions.

**Layout** (mode toggle + wheel/wizard, then selection confirmation card):

```
┌─────────────────────────────────────────┐
│  How are you feeling?                    │  ← display (serif)
│                                          │
│  ╭───────────────╮  ╭───────────────╮   │
│  │   Wizard      │  │    Wheel ●    │   │  ← refined segmented control
│  ╰───────────────╯  ╰───────────────╯   │
│                                          │
│  ╭──── soft warm gradient ────────────╮ │
│  │                                    │ │
│  │   wheel renders here               │ │
│  │   warm-calm rebalanced colors      │ │
│  │                                    │ │
│  ╰────────────────────────────────────╯ │
│                                          │
│  [reset, only when not at rest]          │
└─────────────────────────────────────────┘
```

After a `specific` is selected, the **confirmation card** slides up (`gentle` motion) covering the bottom ~60% of screen, with a `sheet` corner radius:

```
┌─────────────────────────────────────────┐
│   ╭─ glass scrim over the wheel above ╮ │
│                                          │
│  ╭─────────────────────────────────────╮│
│  │  Peaceful · Thankful                ││  ← serif headline
│  │  Happy → Peaceful → Thankful        ││  ← caption (path)
│  │                                      ││
│  │  [definition card — polished]        ││
│  │                                      ││
│  │  Intensity                           ││
│  │  ●●●○○ ────●─────                   ││
│  │                                      ││
│  │  ── Coming soon ───────────────────  ││
│  │  ⚲ Body                          →  ││  ← disabled placeholder rows
│  │  ⌖ Context                        →  ││
│  │  ⚒ Triggers / coping              →  ││
│  │  ▰ Mood scale                     →  ││
│  │                                      ││
│  │  Note (optional)                     ││
│  │  ┌──────────────────────────────┐   ││
│  │  │                              │   ││
│  │  └──────────────────────────────┘   ││
│  │                                      ││
│  │  [    Save check-in    ]             ││
│  ╰─────────────────────────────────────╯│
└─────────────────────────────────────────┘
```

**Acceptance criteria**:
- Mode toggle is a refined segmented control; uses `accentSoft` thumb on `surface` track; `quick` motion on switch. State persists via existing `@AppStorage("checkInMode")`.
- Wheel adopts redesigned core/secondary/specific colors. **No** geometry / gesture / hit-test changes; `WheelViewportTransformTests` must remain green.
- Wizard adopts tokens; grid spacing now `lg` not default; selected state uses accent ring at `card` radius.
- Selection confirmation card uses `sheet` radius, `surfaceElevated`, Liquid Glass scrim above the wheel.
- Definition card: typography polish; previously-shown clinical disclaimer kept; "Sources" disclosure expandable using `DisclosureGroup` styled to tokens. Source list is the global `EmotionDefinitions.referenceSources` (APA, NIH, NIMH, NIH Clinical Center) — not per-emotion (the data model doesn't carry per-emotion citations).
- Placeholder rows under intensity:
  - Visible, dimmed (`textMuted` tint, `surface` background).
  - `disabled(true)` so they accept no taps; trailing chevron is hidden when disabled.
  - Each row carries `accessibilityLabel` (e.g. "Body") + `accessibilityHint` ("Coming soon, currently unavailable").
  - Take final layout space so adding behavior in follow-on specs is purely additive — no relayout needed when functionality lands.
- On Save: insert `FeelingLog`, optionally fire `HealthService.save(log:isEnabled:)` async, then **programmatically switch the selected tab to Today** and present a 2-second inline ribbon ("Saved · 2:14 pm") at the top of Today. The Check In screen resets to its initial state (no selection, wheel at rest) so a return visit starts fresh.
- Tab selection lives on `RootView` as `@State private var selectedTab: AppTab = .today`, mutable from any child via an `@Environment` or `@Binding` indirection so Check In can request the switch.
- Health write behavior preserved (still calls `HealthService.save(log:isEnabled:)` async after insertion; same `healthSyncStatus` plumbing).

### 7.3 Insights

**Purpose**: empty-state-only this cycle. Convey what's coming so users see the trajectory.

```
┌─────────────────────────────────────────┐
│  Insights                                │  ← title (serif)
│                                          │
│           ╭──────────╮                   │
│           │  ▲ chart  │                  │  ← glyph
│           ╰──────────╯                   │
│                                          │
│  Your patterns, soon.                    │  ← serif title
│  Open Feelings will turn your check-ins  │
│  into gentle weekly views.               │
│                                          │
│  ── Coming up ─────────────────────────  │
│                                          │
│  ╭──────────────────────────────────╮   │
│  │ ▲ Trends                          │   │
│  │ When and how often each feeling   │   │
│  │ shows up.                         │   │
│  ╰──────────────────────────────────╯   │
│                                          │
│  ╭──────────────────────────────────╮   │
│  │ ▦ Weekly digest                   │   │
│  │ One calm summary every Sunday.    │   │
│  ╰──────────────────────────────────╯   │
│                                          │
│  ╭──────────────────────────────────╮   │
│  │ ⇪ Therapy bridge                  │   │
│  │ A printable summary you can       │   │
│  │ share with your therapist.        │   │
│  ╰──────────────────────────────────╯   │
│                                          │
│  [  Notify me when this is ready  ]      │  ← OFButton.secondary
└─────────────────────────────────────────┘
```

**Acceptance criteria**:
- Page renders identically whether or not the user has logs.
- "Notify me" toggles a `@AppStorage("notifyOnInsightsReady")` boolean. *No* notification scheduling — value is read by a future spec to decide whether to fire one when Insights ships.
- All three preview cards use `OFCard` with leading SF-Symbol glyph, headline, body copy.

### 7.4 Intentions

**Purpose**: empty-state-only this cycle.

Same shape as Insights but with two preview cards:
- **Set today's intention** — "Choose what you'd like to feel today, and let your check-ins help you notice."
- **Look back** — "See how last week's intentions met your real check-ins."

Same `notifyOnIntentionsReady` `@AppStorage` toggle.

### 7.5 Settings

**Purpose**: existing controls preserved, re-skinned with new components.

Sections (`OFSectionHeader` + grouped `OFListRow`s):

1. **App lock**
   - Toggle: Require Face ID / Touch ID / passcode (`appLockEnabled`)
2. **Reminders**
   - Toggle: Daily reminder (`remindersEnabled`)
   - Time picker: reminder time (when enabled)
3. **Apple Health**
   - Toggle: Sync to Apple Health State of Mind (`healthEnabled`)
   - Status row: "Authorized" / "Not authorized" / "Unavailable on this device"
4. **Export & data**
   - Row → Export CSV
   - Row → Export JSON
5. **About & references**
   - Row → Display name (text field; binds to `@AppStorage("displayName")`)
   - Row → Clinical references (`CLINICAL-REFERENCES.md` viewer)
   - Row → Open Emotion Wheel attribution
   - Row → Licenses (MIT / CC BY-SA)
   - Caption row: app version, build

**Acceptance criteria**:
- All existing controls behave identically (no behavior change).
- Sectioned form uses `OFSectionHeader` and `OFListRow`.
- Liquid Glass on grouped row backgrounds where iOS 26 supports it; falls back to `surface` otherwise.
- Health authorization status pulls from `HealthService.authorizationStatus` and is *read-only* in Settings (the toggle requests authorization on enable).

### 7.6 Lock gate

`LockGateView` keeps its control flow exactly. Visual polish only:
- Centered Face-ID / lock-glyph in `accent`.
- Serif `display` "Locked" headline.
- `body` copy: "Use Face ID to continue."
- `OFButton.primary` "Unlock".
- Locks again on scene-phase transition to inactive (existing behavior).

### 7.7 History (sub-route)

Visual polish only. Logs render as `OFCard`s with the same metadata as on Today. Export menu (CSV / JSON) moves into a top trailing toolbar item. Empty state via `OFEmptyState` ("No check-ins yet").

---

## 8. Wheel re-skin specifics

The wheel is the most complex view (~600 lines). The re-skin is **non-invasive** — every change is in colors, fonts, and stroke weights consumed from tokens; no geometry or transform math changes.

| What changes | What does NOT change |
|---|---|
| Ring fill colors (sourced from redesigned core/secondary/specific) | Angular slice math |
| Label typography (system → tokens) | Hit-test mapping (`WheelViewportTransform.inverted()`) |
| Stroke weight & color (tokens) | Pinch / two-finger rotate / drag-pan gestures |
| Selection ring color & motion (`settle`) | Reset behavior |
| Reset button visual style | Layout helper structure |

**Hard requirement**: `WheelViewportTransformTests` must pass after re-skin. Run before merge.

---

## 9. Copy

All user-facing strings introduced or changed by this redesign are listed for review. Tone: warm, grounded, second-person ("you"), no exclamation points except in success ribbons.

| Where | Copy |
|---|---|
| Today greeting (morning) | "Good morning, {name}." |
| Today greeting (afternoon) | "Good afternoon, {name}." |
| Today greeting (evening) | "Good evening, {name}." |
| Today intention placeholder | "Coming soon — set what you'd like to feel today." |
| Today empty state title | "Today is open." |
| Today empty state body | "Tap below to name how you're feeling." |
| Today empty state CTA | "Start a check-in" |
| Today week summary | "Mostly {Core} this week · {N} check-ins" |
| Today see-all link | "See all history" |
| Check In hero | "How are you feeling?" |
| Check In segmented | "Wizard" / "Wheel" |
| Check In coming-soon row label | "Coming soon" |
| Check In save button | "Save check-in" |
| Check In success ribbon | "Saved · {h:mm a}" |
| Insights title | "Insights" |
| Insights hero title | "Your patterns, soon." |
| Insights hero body | "Open Feelings will turn your check-ins into gentle weekly views." |
| Insights notify CTA | "Notify me when this is ready" |
| Intentions title | "Intentions" |
| Intentions hero title | "Intentions, coming soon." |
| Intentions hero body | "Choose what you'd like to feel — and let your check-ins help you notice." |
| Lock title | "Locked" |
| Lock body | "Use Face ID to continue." |
| Lock CTA | "Unlock" |

`{name}` resolves from a *new* `@AppStorage("displayName")` string introduced by this spec, default `""`. When empty, greetings drop the comma and name (e.g. "Good morning."). The Settings "About & references" section gains an additional row, "Display name", for users who want to set one. A first-launch onboarding flow to prompt for a name is *out of scope* for this cycle.

---

## 10. Accessibility

- **Dynamic Type**: every text role uses `.system(...)` with no fixed point sizes; all surfaces tested at AX5.
- **VoiceOver**: every `OFListRow`, placeholder row, and intensity dot stack has explicit `accessibilityLabel` / `accessibilityHint`. Placeholder rows announce as "Body, coming soon, currently unavailable."
- **Reduce Motion**: `quick`/`gentle`/`settle` collapse to instant. Wheel reset still functional but not animated.
- **Reduce Transparency**: Liquid Glass falls back to `surfaceElevated`.
- **Increase Contrast**: token colors swap to a higher-contrast variant defined alongside the standard tokens.
- **Color contrast**: all text/background pairs meet WCAG AA; verified during implementation.
- **Tap targets**: minimum 44×44 pt; verified for placeholder rows.

---

## 11. Files affected

### New

| Path | Purpose |
|---|---|
| `OpenFeelings/Design/DesignTokens.swift` | All token definitions + `Font.OF.*`, `Color.OF.*`, `CGFloat.OF.*` extensions |
| `OpenFeelings/Design/LiquidGlass.swift` | iOS 26 Liquid Glass adoption helpers |
| `OpenFeelings/Design/Components/OFCard.swift` | |
| `OpenFeelings/Design/Components/OFListRow.swift` | |
| `OpenFeelings/Design/Components/OFEmptyState.swift` | |
| `OpenFeelings/Design/Components/OFSectionHeader.swift` | |
| `OpenFeelings/Design/Components/OFButton.swift` | |
| `OpenFeelings/Design/Components/OFTabBar.swift` | *only if needed* |
| `OpenFeelings/Views/TodayView.swift` | New dashboard surface |
| `OpenFeelings/Views/InsightsView.swift` | Empty-state shell |
| `OpenFeelings/Views/IntentionsView.swift` | Empty-state shell |

### Modified

| Path | Change |
|---|---|
| `OpenFeelings/Views/RootView.swift` | 5-tab structure; default tab = Today; remains wrapped in `LockGateView` |
| `OpenFeelings/Views/CheckInView.swift` | Adopt tokens; selection confirmation card; placeholder rows; success ribbon return path |
| `OpenFeelings/Views/WizardCheckInView.swift` | Token adoption; refined grid; selection ring |
| `OpenFeelings/Views/EmotionWheelView.swift` | Token adoption only; **no** geometry / gesture / transform changes |
| `OpenFeelings/Views/EmotionDefinitionCard.swift` | Typography & spacing polish; `DisclosureGroup` for Sources |
| `OpenFeelings/Views/HistoryView.swift` | Token adoption; sub-route from Today; toolbar export menu |
| `OpenFeelings/Views/SettingsView.swift` | Section-by-section re-skin |
| `OpenFeelings/Views/LockGateView.swift` | Visual polish; same control flow |

### Not modified (intentionally)

- Any `Models/` file (no schema changes).
- Any `Services/` file (no behavior changes).
- `OpenFeelingsApp.swift` (store-mode branching preserved).
- `Info.plist`, `OpenFeelings.entitlements`, `project.yml` *unless* a new SF Symbol or font requires registration (none anticipated).

`xcodegen generate` must be run after adding new files (per `AGENTS.md`).

---

## 12. Verification

### Automated

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build

xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

All 13 existing tests must pass. `WheelViewportTransformTests` must pass — proves the wheel re-skin didn't break selection.

### Manual (iPad simulator, iOS 26.0.1)

- [ ] Cold start → `LockGateView` → Today (default tab).
- [ ] All 5 tabs render and switch with Liquid Glass tab bar; no layout glitches.
- [ ] Today populated state correct: greeting, intention placeholder, today's logs, week summary, "See all" link.
- [ ] Today empty state correct when zero logs today.
- [ ] Tap "Start a check-in" → Check In tab.
- [ ] Wizard mode: pick a path → confirmation card slides up with placeholder rows.
- [ ] Wheel mode: tap, pinch, rotate, drag-pan all still select correctly (regression).
- [ ] Definition card displays with redesigned typography.
- [ ] Save → return to Today → success ribbon "Saved · {time}" appears for 2s.
- [ ] Health sync still works when enabled (verify in Apple Health → Browse → State of Mind).
- [ ] Insights empty state correct; "Notify me" toggle persists across launches.
- [ ] Intentions empty state correct.
- [ ] Settings sections all re-skinned; Lock toggle, Reminders toggle/time, Health toggle, exports, references all functional.
- [ ] "See all history" from Today → re-skinned `HistoryView`; export menu works.
- [ ] Light and dark mode both look intentional, not auto-derived.
- [ ] AX5 Dynamic Type: no clipped text on Today, Check In, Settings.
- [ ] VoiceOver sweep on Today and Check In: labels, hints, order make sense.
- [ ] Reduce Motion: animations collapse to instant.
- [ ] Reduce Transparency: Liquid Glass falls back to solid.

---

## 13. Risk register

| Risk | Mitigation |
|---|---|
| Liquid Glass APIs change in late iOS 26 betas | Wrap in `LiquidGlass.swift` so call sites change in one place |
| Warm-calm color rebalance breaks AA contrast | Implementer must run a contrast check during token authoring; fall back to ±5% lightness adjustment |
| Wheel re-skin accidentally changes hit-test (tests catch geometry but not color-driven layout) | Hold the line: only color, font, stroke-weight changes inside `EmotionWheelView` |
| 5-tab bar feels too busy on iPhone SE-class widths | Verify on iPhone SE simulator at AX5; if labels truncate, switch to icon-only with VoiceOver labels |
| Default-tab change (Check In → Today) confuses returning users | Acceptable; the post-redesign mental model puts dashboard as home, action as one tap away |
| Adding fonts (New York / SF Mono) requires Info.plist registration | No — both are system fonts on iOS 26, no registration needed |

---

## 14. Out of scope (queued follow-ons)

After this spec ships, follow-on specs in approximate order:

1. **Insights surface — functional** — charts, day-of-week / time-of-day distributions, streaks. Covers user-picked dimension *Trends & insights*.
2. **Therapy-bridge export** — PDF / weekly-digest summary view. Covers *Sharing / therapy bridge*.
3. **Richer check-in fields — data model** — extends `FeelingLog` with body / context / trigger / mood-scale fields; SwiftData migration; tests. (Likely paired with #4.)
4. **Richer check-in fields — UI** — wires the placeholder rows from this cycle to actual UI. Covers *Body*, *Context*, *Triggers/coping*, *Mood scale*.
5. **Intentions surface — functional** — set / review intentions. Covers *Goals / intentions*.

*Free-form journaling* was explicitly de-scoped by the user and is not queued.

---

## 15. Approval & next step

When the user approves this spec, the next step is to invoke `superpowers:writing-plans` and produce an implementation plan sequenced as:

1. Add `OpenFeelings/Design/` token file + components (with previews).
2. Refactor `RootView` to 5-tab structure; new empty `TodayView`, `InsightsView`, `IntentionsView`.
3. Build out Today populated + empty states.
4. Re-skin Check In (segmented control, wheel colors, confirmation card, placeholder rows, success ribbon).
5. Build Insights / Intentions empty states.
6. Re-skin Settings + History.
7. Polish & motion pass; AA contrast verification; VoiceOver sweep.
8. Run automated + manual verification per §12.
