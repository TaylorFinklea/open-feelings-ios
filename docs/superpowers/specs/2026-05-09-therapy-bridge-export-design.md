# Therapy-Bridge Export — Design

## Context

Existing exports (`ExportService.swift`, `ExportService+Logseq.swift`) are full data dumps in CSV / JSON / Markdown / Plain text / Logseq. They're keyed off History card share buttons and emit *every* log with no time filter. None of them are appropriate for handing to a therapist who's filing a session into a clinical record.

The therapy-bridge export is a different artifact:

- **Audience:** licensed clinician filing into an EHR.
- **Format:** searchable PDF (vector text, not a rasterized image).
- **Time-bounded:** last 7 days / last 30 days / all time.
- **Detail-tunable:** the patient picks how much to share at generation time.

## Goals

- Generate a single PDF document that summarizes a chosen time window.
- Let the patient pick a **detail level** at generation time:
  - **Patterns only** — pure aggregates, no per-entry text.
  - **Patterns + notable** — aggregates *and* a short list (≤5) of notable entries.
  - **Full per-entry list** — every check-in in the window, paginated.
- Reuse `InsightsDataset.build(...)` for aggregation rather than re-deriving counts.
- Surface the new export from Settings (not the per-card share menu — this is a deliberate one-off, not a per-entry share).

## Non-goals

- Custom date ranges (two date pickers). Defer to v2; the three preset windows cover the common case ("since last session" ≈ 7d, "monthly check-in" ≈ 30d).
- Tables of contents, hyperlinks, bookmarks. Plain forward-reading PDF only.
- Sharing intentions with reflections to *other* targets (still tracked separately in the existing per-entry share menu and the deferred export work).
- Shareable JSON/Markdown variant of this report. PDF only for v1.
- Custom branding, logos, header images. The PDF is utilitarian on purpose — it shouldn't look like a "wellness app brochure."
- Anonymization toggles or PII redaction. The app stores no PII (no name, email, account); a therapist already has the patient's identity.

## Architecture

### Layers

```
TherapyReportSettingsView          (UI: Settings entry, pickers, Generate button, share sheet)
        │
        ▼
TherapyReportPDFService            (orchestrates UIGraphicsPDFRenderer + per-page SwiftUI rendering)
        │
        ├── TherapyReportData      (value type: filtered logs + intentions + InsightsDataset for the window)
        │       └── uses InsightsDataset.build(...)
        │
        └── TherapyReportPage views (SwiftUI views, one per page, designed to fit US Letter)
```

Three new files plus one reused module. Surface area is contained.

### `TherapyReportData` (new value type)

```swift
struct TherapyReportData {
    enum Window { case last7Days, last30Days, allTime }
    enum DetailLevel { case patternsOnly, patternsAndNotable, fullEntries }

    let window: Window
    let detailLevel: DetailLevel
    let generatedAt: Date
    let dataset: InsightsDataset            // reused aggregation
    let intentions: [IntentionSummary]      // intentions-with-reflections in the window
    let notableLogs: [FeelingLog]           // top-5 by intensity desc, then by has-note, then recency
    let allLogs: [FeelingLog]               // populated only when detailLevel == .fullEntries

    static func build(window: Window,
                      detailLevel: DetailLevel,
                      logs: [FeelingLog],
                      intentions: [Intention],
                      now: Date = .now) -> TherapyReportData
}

struct IntentionSummary {
    let date: Date
    let text: String
    let reflection: String           // empty if not reflected
    let topCoreNamesOnDay: [String]  // reuses IntentionDayFelt.topCoreNames
}
```

Aggregation rules (pure-logic, fully testable):

- **Window cutoff:** map `Window` → `InsightsPeriod` (`last7Days`→`.week`, `last30Days`→`.month`, `allTime`→`.all`) and reuse `InsightsDataset.build(...)`.
- **`notableLogs`:** filter to logs in the window. Sort by `intensity ?? 0` desc, then `note.isEmpty == false` first, then `createdAt` desc. Take first 5.
- **`allLogs`:** only populated when `detailLevel == .fullEntries`; same window filter, sorted by `createdAt` desc.
- **`intentions`:** filter to intentions whose `date` falls in the window. Sort by `date` desc. For each, look up `IntentionDayFelt.topCoreNames(in: ..., logs: logs)`.

### Page composition

A `TherapyReport` always has these pages, in order:

1. **Cover page** — title ("Open Feelings — Period Summary"), generated date, window label, detail-level label. Disclaimer footer ("This is a self-reported emotion log, not a clinical assessment.").
2. **Patterns page** — `dataset.totalCount` and `currentStreak`, top-3 cores by count with color swatches, day-of-week histogram (text-based bar chart since we don't need live Swift Charts in the PDF), avg intensity from `intensityTrend`, top body region.
3. **Notable entries page** *(only when `detailLevel != .patternsOnly`)* — up to 5 entries, each one block: date+time, emotion path, intensity dots, note (truncated to 6 lines), trigger/coping bullets if present.
4. **Per-entry pages** *(only when `detailLevel == .fullEntries`)* — paginate `allLogs` into pages of 5 entries each. Each page has a small "Page X of Y" footer.
5. **Intentions page** *(only when `intentions` is non-empty)* — list of intentions in window with their reflections (or "no reflection yet"), one per row.

Page count formula:
- `patternsOnly` with no intentions → 2 pages (cover + patterns)
- `patternsOnly` with intentions → 3 pages
- `patternsAndNotable` typical → 3-4 pages
- `fullEntries` typical → 3 + ceil(logs/5) pages

### `TherapyReportPDFService` (new)

```swift
@MainActor
enum TherapyReportPDFService {
    static func writePDF(_ report: TherapyReportData) throws -> URL
}
```

Implementation:

1. Allocate a `UIGraphicsPDFRenderer` with US Letter (612×792 pt) and standard metadata (creator: "Open Feelings", title: "Period Summary").
2. Build the ordered list of `AnyView` pages from `report` (functions that return `some View`, wrapped via `AnyView`).
3. For each page: `context.beginPage()`, then use `ImageRenderer` to render the SwiftUI view directly to the current PDF `CGContext`. `ImageRenderer.render { size, renderClosure in renderClosure(context.cgContext) }` produces vector text (not raster) when the destination context is a PDF context. This is the key technique — see Apple's `ImageRenderer` documentation under "Drawing to a Canvas".
4. Write the resulting `Data` to `FileManager.default.temporaryDirectory/OpenFeelings-Period-Summary-<yyyy-MM-dd>.pdf`.
5. Return the URL.

### `TherapyReportSettingsView` (new)

A new row added to `SettingsView` under the "Exports" section reads "Period summary for therapist". Tapping it pushes `TherapyReportSettingsView` which has:

- Picker: **Window** — Last 7 days / Last 30 days / All time
- Picker: **Detail level** — Patterns only / Patterns + notable entries / Full check-in list
- A short helper paragraph explaining what gets included at the chosen detail level (1-2 sentences that change as the user changes detail).
- An `OFButton(.primary)` "Generate PDF" that triggers PDF creation and opens the share sheet.
- Same `ShareItem` + alert error pattern as `HistoryView`'s existing exports.

### Where it lives in `SettingsView`

The existing exports are surfaced from per-entry History cards. The therapy report is a distinct UX from those — it's not "share this entry," it's "summarize the period." So it lives in **Settings → Exports** as its own row, alongside the existing "Apple Journal / Day One / Notes" hand-off explanation.

## Page rendering details

### SwiftUI views for pages

Each page is a `View` sized to fit US Letter content area (612×792 pt with 0.5" margins → content area 540×720 pt). Examples:

```swift
struct TherapyCoverPage: View {
    let report: TherapyReportData
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Open Feelings")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Period Summary")
                .font(.system(size: 32, weight: .semibold))
            VStack(alignment: .leading, spacing: 6) {
                row("Window", report.window.displayName)
                row("Detail level", report.detailLevel.displayName)
                row("Generated", report.generatedAt.formatted(date: .abbreviated, time: .shortened))
                row("Check-ins in window", "\(report.dataset.totalCount)")
            }
            .font(.system(size: 14))
            Spacer()
            Text("This document summarizes self-reported emotion check-ins. It is not a clinical assessment.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(width: 540, height: 720, alignment: .topLeading)
        .padding(36)
        .background(Color.white)
    }
}
```

Note these views deliberately use **system fonts**, not `Font.OF` design tokens. The PDF should look clinical/neutral, not warm-and-cozy. Using system fonts also means no third-party font bundling concerns.

### Day-of-week histogram (text-based)

Avoid Swift Charts in PDF rendering — `ImageRenderer` + Charts has historically had layout glitches. Render a plain text histogram:

```
Mon  ████████  4
Tue  ██  1
Wed  ████████████  6
Thu  ██  1
Fri  ████████████████  8
Sat  —  0
Sun  ████  2
```

The "█" chars scale to the max count in the period. This renders perfectly as vector text and survives PDF compression.

### Color swatches for top cores

Render small filled `Circle()` shapes at the cores' hex colors. Pure SwiftUI, vectorizes correctly into PDF.

## Edge cases

- **Empty window** (no logs): Cover page renders with `0` check-ins; the patterns page reads "No check-ins captured in this window." No notable / entries / intentions pages. PDF is 1 page total.
- **Single log:** All sections render normally with N=1; histogram has one bar.
- **Very long note:** truncate to ~6 lines with an ellipsis. Full text remains in the underlying log; this report is a summary.
- **No intentions in window:** intentions page is omitted entirely.
- **All-time window with hundreds of logs in `fullEntries`:** still works (paginated 5 per page); a 200-log all-time export at 5/page = 40 entry pages, ~43 pages total. This is the patient's call.
- **Empty reflection but filled intention:** show intention text, label reflection as "no reflection yet" (italic, muted).
- **Document title localization:** v1 ships English only. Title and section headers are static strings.

## Testing

Pure-logic tests are the priority — PDF rendering itself is hard to assert (file exists, non-zero bytes, "OpenFeelings-Period-Summary" filename are achievable but shallow).

New `TherapyReportDataTests.swift` (~10 methods):

- `testLast7DaysFiltersWindowCorrectly` — logs at day -1, -7, -8 → 2 in window.
- `testNotableLogsSortByIntensityThenNoteThenRecency` — fixture with mixed intensities, some with notes; verify the top-5 ordering.
- `testNotableLogsCappedAtFive` — 10 candidates → 5 returned.
- `testFullEntriesPopulatedOnlyForFullDetailLevel` — `patternsOnly` → empty `allLogs`; `fullEntries` → all-in-window.
- `testIntentionsFilteredByWindow` — intentions on day -3, -8 with `last7Days` → only -3 included.
- `testIntentionSummaryCarriesReflection` — verify the `reflection` and `topCoreNamesOnDay` populate correctly.
- `testEmptyWindowReturnsZeroAggregates` — no logs, `dataset.totalCount == 0`, `notableLogs.isEmpty`.
- `testWindowMapsToInsightsPeriod` — `.last7Days` → `.week`, etc.

Plus one PDF smoke test:

- `testPDFGenerationProducesNonEmptyDocument` — mocks a small report, calls `TherapyReportPDFService.writePDF(...)`, verifies the URL exists, file size > 1KB, file extension is `.pdf`.

UI tests for the Settings flow are deferred per the existing roadmap backlog item.

## Files affected

**New:**
- `OpenFeelings/Services/TherapyReportData.swift` — value type + aggregation
- `OpenFeelings/Services/TherapyReportPDFService.swift` — `UIGraphicsPDFRenderer` orchestration
- `OpenFeelings/Views/TherapyReport/TherapyReportSettingsView.swift` — entry view (window picker, detail picker, Generate button)
- `OpenFeelings/Views/TherapyReport/TherapyReportPages.swift` — SwiftUI page views (cover, patterns, notable, entries, intentions)
- `OpenFeelingsTests/TherapyReportDataTests.swift` — aggregation tests

**Modified:**
- `OpenFeelings/Views/SettingsView.swift` — add a `NavigationLink` row under the existing exports section: "Period summary for therapist" → `TherapyReportSettingsView`.

**Untouched:**
- `ExportService.swift` and `ExportService+Logseq.swift` — out of scope; existing exports continue to work as-is.
- `InsightsDataset.swift` — read-only consumption.
- `Intention.swift` — read-only consumption.
- `IntentionDayFelt.swift` — read-only consumption.

## Verification

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED + ~177 passing tests (168 existing + ~9 new).

**Manual on simulator with seeded data spanning last 30 days, mixed intensities, some notes, several intentions+reflections:**

1. Settings → Exports → "Period summary for therapist" pushes the picker view.
2. Default selection: Last 7 days / Patterns + notable.
3. Helper text updates as detail level changes.
4. Tap Generate → loading state → share sheet appears with `OpenFeelings-Period-Summary-2026-05-09.pdf`.
5. AirDrop to Mac, open in Preview:
   - Page 1 cover: title, window, detail level, generated date, count, disclaimer footer.
   - Page 2 patterns: total + streak, top-3 cores with color swatches, day-of-week histogram, avg intensity, top body region.
   - Page 3 notable entries (since default is patternsAndNotable): up to 5 entries, each with date/emotion/intensity dots/truncated note.
   - If there are intentions in the window, page 4 is intentions + reflections.
6. Switch to "Patterns only" → re-generate → only pages 1-2 (+ intentions if present).
7. Switch to "Full check-in list" → re-generate → pages multiply by ceil(logs/5).
8. Switch to "All time" with no logs (fresh user) → 1-page PDF that says "No check-ins captured in this window."
9. PDF text is searchable in Preview (Cmd-F finds emotion names, dates, etc.) — confirms vector text rendering, not rasterized.
10. Dynamic Type does not affect the PDF (it uses fixed sizes for stability).
11. VoiceOver in the Settings flow reads the pickers and Generate button correctly.

## Out of scope (revisited)

- Custom date ranges (two `DatePicker`s) — v2.
- Anonymization / PII redaction — N/A (app captures no PII).
- Markdown variant of this report — defer; PDF satisfies the "filed into clinical record" use case.
- Multi-language support — English only for v1.
- Bundled fonts / brand styling — keep utilitarian.
- Shareable URL or web-viewer — local PDF + iOS share sheet is sufficient.
- Auto-redacting / summarizing notes via on-device LLM — interesting but out of scope.

## Implementation order

1. **`TherapyReportData` + tests first** — the math is the highest-risk part. Lock it in before touching UI or PDF rendering.
2. **`TherapyReportPDFService` skeleton** — hello-world PDF (one page, just the cover) to validate the `ImageRenderer` → PDF context flow.
3. **Page views** — cover, patterns, notable, entries, intentions. Each is a stateless SwiftUI view receiving the report.
4. **PDF service composition** — wire the page list per detail level + intentions presence.
5. **Settings entry view** — the pickers and Generate button.
6. **`SettingsView` row** — add the navigation link.
7. **Manual sim verification** with seeded data per the verification checklist above.
8. **Single feature branch** off main; one feature commit; build-bump commit; release-marker commit.
