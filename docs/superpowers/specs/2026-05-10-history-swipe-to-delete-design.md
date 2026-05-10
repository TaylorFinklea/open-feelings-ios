# Spec: History — swipe-to-delete a check-in

> **Tier hint:** Haiku/Sonnet. Bog-standard SwiftUI `.swipeActions` +
> confirmation alert. Touches one view file plus a small unit test for the
> deletion helper. ~50 lines net.

## Context

`HistoryView` lists every saved `FeelingLog` as a vertical scroll of
`OFCard`s. There's currently no per-card destructive affordance — a user
who saved a check-in by accident has to delete the entire SwiftData store
to remove it. That's a real friction point and a common reason a
private-by-design app feels punitive.

Add a swipe-to-delete affordance, gated by a confirmation alert because
delete is irreversible (CloudKit's tombstoning is automatic on the model
mutation; there's no Undo).

## Goals

- A right-edge swipe on any `LogCard` reveals a destructive **Delete**
  action.
- Tapping Delete opens an alert: title "Delete this check-in?", body
  "This permanently removes the entry from this device and any iCloud-
  synced devices.", actions **Cancel** (default) and **Delete**
  (destructive).
- On confirm, the log is removed from the SwiftData context. CloudKit
  syncs the deletion to other signed-in devices automatically.
- Filter banner state (if any) survives a delete — the banner stays up,
  the list re-renders without the deleted entry.
- Empty-state copy already handles "filtered vs unfiltered, zero rows" — no
  change needed there.

## Non-goals

- Multi-select / bulk delete.
- Undo (would require a snapshot of the log + a 5-second toast). Could be a
  v2 once we know whether users miss it.
- Edit affordance on the same card. Separate spec.
- Animated removal transitions beyond SwiftUI's default.
- Deletion of intentions from the Intentions tab — separate spec.

## Architecture / approach

A SwiftUI `.swipeActions` modifier on the inner card view, wired to a
small alert state and a delete helper that operates on the
`@Environment(\.modelContext)`.

```swift
ForEach(logs) { log in
    OFCard { LogCard(log: log) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = log
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "Delete") {
            pendingDelete = log
        }
}
```

`@State private var pendingDelete: FeelingLog?` triggers the alert; the
alert's destructive button calls `delete(log:)`.

```swift
.alert("Delete this check-in?", isPresented: deleteAlertBinding) {
    Button("Cancel", role: .cancel) {}
    Button("Delete", role: .destructive) {
        if let log = pendingDelete {
            delete(log: log)
        }
        pendingDelete = nil
    }
} message: {
    Text("This permanently removes the entry from this device and any iCloud-synced devices.")
}
```

```swift
private var deleteAlertBinding: Binding<Bool> {
    Binding(
        get: { pendingDelete != nil },
        set: { if !$0 { pendingDelete = nil } }
    )
}

private func delete(log: FeelingLog) {
    modelContext.delete(log)
    try? modelContext.save()
}
```

The `.accessibilityAction(named: "Delete")` adds a VoiceOver-discoverable
delete affordance — VoiceOver users can't swipe-reveal, so they need an
explicit action via the rotor.

## Files affected

### `OpenFeelings/Views/HistoryView.swift`

- Add `@Environment(\.modelContext) private var modelContext` (already
  present in some views; add if absent).
- Add `@State private var pendingDelete: FeelingLog?`.
- Modify the `ForEach` block in `content` to attach `.swipeActions(...)`
  and `.accessibilityAction(...)`.
- Add `.alert(...)` modifier on the outer view (sibling of the existing
  `.sheet(item: $shareItem)` modifier).
- Add `delete(log:)` private helper.
- Add `deleteAlertBinding` private computed property.

No new files. No model changes. No `project.yml` change. `xcodegen` does
not need to be re-run.

### `OpenFeelingsTests/HistoryDeleteTests.swift` (new)

Test the `delete(log:)` semantics through a free function. Refactor the
helper out of the view into a small file-scope or static function so it
can be tested:

```swift
// In HistoryView.swift, replace `private func delete(log:)` with:
extension HistoryView {
    static func deleteLog(_ log: FeelingLog, in context: ModelContext) {
        context.delete(log)
        try? context.save()
    }
}

// Then the inline call site becomes:
HistoryView.deleteLog(log, in: modelContext)
```

Tests:

```swift
import XCTest
import SwiftData
@testable import OpenFeelings

@MainActor
final class HistoryDeleteTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self, Intention.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func sampleLog() -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        return FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: 3,
            note: "test"
        )
    }

    func testDeleteLogRemovesItFromTheContext() throws {
        let ctx = try makeContext()
        let log = sampleLog()
        ctx.insert(log)
        try ctx.save()

        let descriptor = FetchDescriptor<FeelingLog>()
        XCTAssertEqual(try ctx.fetch(descriptor).count, 1)

        HistoryView.deleteLog(log, in: ctx)

        XCTAssertEqual(try ctx.fetch(descriptor).count, 0)
    }

    func testDeleteLogIsIdempotentIfAlreadyRemoved() throws {
        let ctx = try makeContext()
        let log = sampleLog()
        ctx.insert(log)
        try ctx.save()

        HistoryView.deleteLog(log, in: ctx)
        // Calling again should not crash even though the object is gone.
        HistoryView.deleteLog(log, in: ctx)

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FeelingLog>()).count, 0)
    }
}
```

If `HistoryView` is currently a `struct HistoryView: View {` (no
visibility annotation), keep it that way — it's `internal` by default so
the test target can see it. Make the new `static func deleteLog` `static`
inside an `extension HistoryView` so it doesn't depend on view state.

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

Expected: BUILD SUCCEEDED + 191 + 2 new = 193 passing tests.

### Manual verification on iPad (A16) iOS 26.0.1

With at least 3 saved check-ins:

1. Open History tab → swipe one card from right to left. **Delete** button
   reveals.
2. Tap Delete → alert appears with the copy specified above.
3. Tap **Cancel** → alert dismisses, card stays.
4. Swipe again, tap Delete, then tap **Delete** in the alert. Card
   animates out of the list.
5. Reload the app from cold (Cmd+Shift+H twice in simulator, force-quit,
   relaunch). Deleted card is still gone — confirms persistence.
6. Apply a filter via Insights drill-down, return to History. Swipe-delete
   one filtered card. The filter banner stays up, list updates.
7. Enable VoiceOver. Focus a card. Open the rotor → Actions. The "Delete"
   action should be available; activating it triggers the same alert.

## Edge cases

- **Empty after delete.** `HistoryView`'s existing empty-state copy
  handles zero rows — no change needed.
- **CloudKit sync.** `modelContext.delete(log)` plus `save()` is the only
  thing needed; `NSPersistentCloudKitContainer` (which SwiftData uses
  under the hood for CloudKit) propagates the deletion. No special
  handling.
- **In-flight HealthKit write.** If the log was just saved and HealthKit
  writes asynchronously (per `CheckInView.save()`), deletion of the
  SwiftData log doesn't retract the HealthKit sample. That's existing
  behavior — out of scope to address here.
- **Concurrent delete from another device.** SwiftData handles "already
  deleted" gracefully (the second delete is a no-op). The
  `testDeleteLogIsIdempotentIfAlreadyRemoved` test pins this contract.

## Out of scope

- Undo / 5-second toast — could revisit if users complain.
- Editing.
- Animated swipe-action background color tween beyond defaults.
- Bulk delete.
- Deleting from the Today preview cards (not in this spec; could mirror
  this pattern later).
- Adding a "Delete all" affordance under Settings.

## Implementation order

1. Add `pendingDelete` state + `deleteAlertBinding` + the alert.
2. Refactor the inline delete into `static func deleteLog(_:in:)`.
3. Attach `.swipeActions(...)` and `.accessibilityAction(...)`.
4. Write the tests.
5. `xcodegen generate` (no, actually only needed if you added a new
   *file*; for a modify-only change to existing files, skip it). Build,
   run tests.
6. Single feature commit.
