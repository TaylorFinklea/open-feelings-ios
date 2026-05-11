# Spec: Unit tests for TherapyReportPDFService page composition

> **Tier hint:** Sonnet. Small refactor (extract pure page-list builder
> from the UIGraphicsPDFRenderer plumbing) plus a tests-only deliverable.
> No UIKit at test time.

## Context

Build 14 shipped `OpenFeelings/Services/TherapyReportPDFService.swift`,
which renders a `TherapyReportData` to a multipage PDF. The actual page
*composition* logic — how many pages, in what order, of which kinds — lives
inside a `private static func makePages(for:) -> [AnyView]` on the service.

The composition rules are non-trivial:

- Cover + Patterns pages always render.
- `.patternsOnly` → no extra pages, plus optional Intentions.
- `.patternsAndNotable` → adds a Notable page *only if* `notableLogs` is
  non-empty, plus optional Intentions.
- `.fullEntries` → paginates `allLogs` into chunks of 5 with "Page X of Y"
  footers, plus optional Intentions.
- Intentions page is omitted entirely when `report.intentions` is empty.

None of that has test coverage today. The risk is real: a regression that
quietly drops the Notable page, or that double-counts the entries page, or
that mis-paginates a 6-entry list as 1-page-of-6 instead of 2-pages-of-5+1.

## Goals

- A pure, UIKit-free, value-typed *page-list* representation of what the
  PDF will contain.
- A pure builder that maps `TherapyReportData` → `[Page]`.
- `TherapyReportPDFService.writePDF(_:)` consumes the builder; rendering is
  the only UIKit-touching code.
- Unit tests for the builder cover all four detail-level branches plus
  intentions presence/absence.

## Non-goals

- Tests for the rendered PDF bytes. PDF byte-output is hard to assert on
  without snapshot infrastructure; not worth the effort.
- Changes to the per-page SwiftUI views (`TherapyCoverPage`,
  `TherapyPatternsPage`, `TherapyEntriesPage`, `TherapyIntentionsPage`).
- Changes to filename, paper size (US Letter), or the
  `kCGPDFContextCreator` metadata.

## Approach

Introduce a small enum that names each kind of page, plus a struct for the
per-entries-page slice. The page-list builder returns `[TherapyReportPage]`;
the renderer maps that to `[AnyView]` and runs them through
`UIGraphicsPDFRenderer`.

### `OpenFeelings/Services/TherapyReportPDFService.swift`

Add at top of file (before the enum `TherapyReportPDFService`):

```swift
/// Value-typed manifest of a single page in the PDF. Pure data — render
/// logic stays in TherapyReportPDFService. Tests assert on the page list
/// without instantiating any SwiftUI views or PDF contexts.
enum TherapyReportPage: Equatable {
    case cover
    case patterns
    case notable    // present only when patternsAndNotable + notableLogs non-empty
    case entries(pageNumber: Int, totalPages: Int)
    case intentions

    var isEntries: Bool {
        if case .entries = self { return true }
        return false
    }
}
```

Replace `makePages(for:)` with two functions: a pure builder that returns
`[TherapyReportPage]`, and an `AnyView`-producing renderer that maps a
`TherapyReportPage` to its `View`. The pure builder is what gets tested.

```swift
@MainActor
enum TherapyReportPDFService {
    // ... existing pageSize, entriesPerPage, writePDF body unchanged ...

    /// Pure page-list builder. The shape of the PDF is determined here;
    /// rendering is downstream.
    static func pages(for report: TherapyReportData) -> [TherapyReportPage] {
        var pages: [TherapyReportPage] = [.cover, .patterns]

        switch report.detailLevel {
        case .patternsOnly:
            break

        case .patternsAndNotable:
            if !report.notableLogs.isEmpty {
                pages.append(.notable)
            }

        case .fullEntries:
            let chunks = stride(from: 0, to: report.allLogs.count, by: entriesPerPage).count
            for index in 0..<chunks {
                pages.append(.entries(pageNumber: index + 1, totalPages: chunks))
            }
        }

        if !report.intentions.isEmpty {
            pages.append(.intentions)
        }

        return pages
    }

    /// Renders one page as a SwiftUI view. Drives the PDF context's per-page
    /// call. UIKit-only; not tested directly.
    @ViewBuilder
    private static func view(for page: TherapyReportPage,
                             report: TherapyReportData) -> some View {
        switch page {
        case .cover:
            TherapyCoverPage(report: report)
        case .patterns:
            TherapyPatternsPage(report: report)
        case .notable:
            TherapyEntriesPage(
                title: "Notable entries",
                logs: report.notableLogs,
                pageNumber: nil,
                totalPages: nil
            )
        case .entries(let pageNumber, let totalPages):
            let start = (pageNumber - 1) * entriesPerPage
            let end = min(start + entriesPerPage, report.allLogs.count)
            let chunk = Array(report.allLogs[start..<end])
            TherapyEntriesPage(
                title: "Check-ins",
                logs: chunk,
                pageNumber: pageNumber,
                totalPages: totalPages
            )
        case .intentions:
            TherapyIntentionsPage(summaries: report.intentions)
        }
    }
}
```

Then update `writePDF(_:)` to use the new builder. Replace the existing
`let pages = makePages(for: report)` block with:

```swift
let pageList = pages(for: report)
let data = renderer.pdfData { ctx in
    for page in pageList {
        ctx.beginPage()
        let imageRenderer = ImageRenderer(
            content: view(for: page, report: report)
                .frame(width: pageSize.width, height: pageSize.height)
        )
        imageRenderer.render { _, render in
            render(ctx.cgContext)
        }
    }
}
```

Delete the now-unused private `makePages(for:) -> [AnyView]` function.

### `OpenFeelingsTests/TherapyReportPDFServiceTests.swift` (new)

Note: `TherapyReportPDFService` is `@MainActor`. Tests inherit by being
`@MainActor` themselves.

```swift
import XCTest
@testable import OpenFeelings

@MainActor
final class TherapyReportPDFServiceTests: XCTestCase {

    private func log(intensity: Int? = nil, note: String = "", daysAgo: Double = 1) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let l = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: intensity,
            note: note
        )
        l.createdAt = Date().addingTimeInterval(-daysAgo * 86_400)
        return l
    }

    private func intention(daysAgo: Int, text: String = "be kind", reflection: String = "") -> IntentionSummary {
        IntentionSummary(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            text: text,
            reflection: reflection,
            topCoreNamesOnDay: []
        )
    }

    private func report(
        detailLevel: TherapyReportData.DetailLevel,
        logs: [FeelingLog] = [],
        notableLogs: [FeelingLog] = [],
        intentions: [IntentionSummary] = []
    ) -> TherapyReportData {
        TherapyReportData(
            window: .last7Days,
            detailLevel: detailLevel,
            generatedAt: Date(),
            dataset: .empty,
            intentions: intentions,
            notableLogs: notableLogs,
            allLogs: logs
        )
    }

    // MARK: - Pages always present

    func testCoverAndPatternsAlwaysAppear() {
        let p = TherapyReportPDFService.pages(for: report(detailLevel: .patternsOnly))
        XCTAssertEqual(p.first, .cover)
        XCTAssertEqual(p.dropFirst().first, .patterns)
    }

    // MARK: - .patternsOnly

    func testPatternsOnlyOmitsNotableEvenIfNotableLogsPresent() {
        // Defensive: even if upstream populates notableLogs by mistake,
        // patternsOnly must not render them.
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsOnly, notableLogs: [log()])
        )
        XCTAssertFalse(p.contains(.notable))
    }

    func testPatternsOnlyWithoutIntentionsIsExactlyTwoPages() {
        let p = TherapyReportPDFService.pages(for: report(detailLevel: .patternsOnly))
        XCTAssertEqual(p, [.cover, .patterns])
    }

    // MARK: - .patternsAndNotable

    func testPatternsAndNotableSkipsNotableWhenNotableLogsEmpty() {
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsAndNotable, notableLogs: [])
        )
        XCTAssertFalse(p.contains(.notable))
    }

    func testPatternsAndNotableIncludesNotablePageWhenLogsPresent() {
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsAndNotable, notableLogs: [log()])
        )
        XCTAssertEqual(p.filter { $0 == .notable }.count, 1)
    }

    // MARK: - .fullEntries pagination

    func testFullEntriesNoLogsProducesZeroEntriesPages() {
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: [])
        )
        XCTAssertEqual(p.filter(\.isEntries).count, 0)
    }

    func testFullEntries5LogsProduces1Page() {
        let logs = (0..<5).map { _ in log() }
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: logs)
        )
        let entries = p.filter(\.isEntries)
        XCTAssertEqual(entries.count, 1)
        if case .entries(let n, let total) = entries.first {
            XCTAssertEqual(n, 1)
            XCTAssertEqual(total, 1)
        } else {
            XCTFail("Expected one .entries page")
        }
    }

    func testFullEntries6LogsProduces2PagesNumbered() {
        let logs = (0..<6).map { _ in log() }
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: logs)
        )
        let entries = p.filter(\.isEntries)
        XCTAssertEqual(entries.count, 2)
        if case .entries(let n1, let t1) = entries[0],
           case .entries(let n2, let t2) = entries[1] {
            XCTAssertEqual([n1, n2], [1, 2])
            XCTAssertEqual([t1, t2], [2, 2])
        } else {
            XCTFail("Expected two .entries pages")
        }
    }

    func testFullEntries12LogsProduces3Pages() {
        let logs = (0..<12).map { _ in log() }
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: logs)
        )
        XCTAssertEqual(p.filter(\.isEntries).count, 3)
    }

    // MARK: - Intentions page presence

    func testIntentionsPageOmittedWhenIntentionsEmpty() {
        let p = TherapyReportPDFService.pages(for: report(detailLevel: .patternsOnly))
        XCTAssertFalse(p.contains(.intentions))
    }

    func testIntentionsPageAppearsLastWhenIntentionsPresent() {
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsOnly,
                        intentions: [intention(daysAgo: 1)])
        )
        XCTAssertEqual(p.last, .intentions)
    }

    func testIntentionsAppearsAfterEntriesPagesOnFullDetail() {
        let logs = (0..<6).map { _ in log() }
        let p = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries,
                        logs: logs,
                        intentions: [intention(daysAgo: 1)])
        )
        // last page is intentions, the one before is an entries page
        XCTAssertEqual(p.last, .intentions)
        XCTAssertTrue(p.dropLast().last?.isEntries == true)
    }

    // MARK: - Smoke

    func testEmptyReportProducesCoverAndPatternsOnly() {
        let p = TherapyReportPDFService.pages(for: report(detailLevel: .patternsAndNotable))
        XCTAssertEqual(p, [.cover, .patterns])
    }
}
```

The test fixtures use `TherapyReportData.empty` (which already exists; if
not, hand-construct via `TherapyReportData(window:detailLevel:generatedAt:dataset:intentions:notableLogs:allLogs:)`).
The `dataset: .empty` reuse is safe because we only assert on page
*identity and pagination math*, never on dataset contents.

If `TherapyReportData.init` is currently `private` or `internal`, no change
needed — both work for tests via `@testable import OpenFeelings`. If it
takes more arguments than shown above, just pass through whatever the
current signature demands; the test doesn't care about those values.

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

Expected: BUILD SUCCEEDED + 210 + ~12 new = ~222 passing tests.

Plus a smoke validation that PDF generation still works end-to-end —
nothing automated, but you should be able to open the app in the
simulator and trigger Settings → Sharing → Period summary for therapist
→ Generate PDF, and confirm the share sheet still opens with a file.

## Implementation order

1. Add the `TherapyReportPage` enum at top of `TherapyReportPDFService.swift`.
2. Add the new `pages(for:)` static method and `view(for:report:)` view
   builder. Keep `makePages(for:)` temporarily.
3. Update `writePDF(_:)` to use `pages(for:)` + `view(for:report:)`.
4. Build green — confirm no behavior change.
5. Delete `makePages(for:)`.
6. Add `TherapyReportPDFServiceTests.swift`. Run.
7. Single feature commit.

## Out of scope

- PDF byte-output snapshot tests.
- Tests for `TherapyReportPDFService.writePDF(_:)` itself (it's a thin
  shell over `UIGraphicsPDFRenderer`).
- Localization of page titles.
- Changes to the per-page SwiftUI views.
