# Spec: History — edit the note on a saved check-in

> **Tier hint:** Sonnet. Real user feature, tightly scoped to *note text
> only*. Adds a modal sheet, a small NoteEditor view, and persistence
> through the existing SwiftData context. ~80 lines of view code, 3-4
> unit tests, no model schema change.

## Context

Today, `HistoryView`'s `LogCard` renders `log.note` via `JournalText`
read-only. A user who saved a check-in in a hurry has no way to clean up
or expand the note afterward. Emotion / intensity / body regions stay
read-only by design — the check-in captures a *moment*, not an evolving
record — but the **note** is genuinely a reflective field that benefits
from later editing.

Add a "Edit note" affordance on each card. Tapping opens a sheet with a
multi-line text editor pre-filled with the current note; **Save** writes
back to SwiftData (which CloudKit-syncs automatically), **Cancel** drops
the edit.

## Goals

- Each `LogCard` exposes an "Edit note" button (a `JournalText` adjacent
  control, not a swipe action — swipe is reserved for Delete).
- Tap → modal sheet with a `TextEditor` pre-filled with `log.note`.
- Save persists via the existing `@Environment(\.modelContext)`.
- Cancel discards. Sheet dismisses on either.
- The editor is also reachable via a VoiceOver action
  `.accessibilityAction(named: "Edit note")` on the card.
- No schema change. No HealthKit re-write (the State of Mind sample is a
  *moment* — editing the note after the fact does not retroactively
  update HealthKit).

## Non-goals

- Editing emotion / intensity / body regions / context / triggers /
  coping / mood. Out of scope for v1 — see "Out of scope" below for the
  reasoning.
- Inline (non-sheet) editing on the card itself.
- Rich-text formatting / markdown. Plain text only.
- Undo. The user can re-edit.
- Edit history / audit trail.
- Bulk edit.

## Approach

A modal sheet binding `Identifiable?` triggers presentation, mirroring
the existing `pendingDelete` + `.alert` pattern in `HistoryView`. The
sheet body is a new private `NoteEditorSheet` view.

### `OpenFeelings/Views/HistoryView.swift`

Add state at the top of `HistoryView`:

```swift
@State private var editingLog: FeelingLog?
```

Attach the sheet alongside the existing `.alert(...)` modifier:

```swift
.sheet(item: $editingLog) { log in
    NoteEditorSheet(log: log) { newNote in
        Self.updateNote(log, to: newNote, in: modelContext)
    }
}
```

`FeelingLog` is a SwiftData `@Model` class so it's automatically
identifiable by `id`. Confirm it conforms to `Identifiable` (it should
via SwiftData; if not, add a one-line conformance: `extension FeelingLog: Identifiable {}`).

Add the swipe-action + accessibility-action entry points alongside the
existing Delete button:

```swift
OFCard { LogCard(log: log) }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
            pendingDelete = log
        } label: {
            Label("Delete", systemImage: "trash")
        }
        Button {
            editingLog = log
        } label: {
            Label("Edit note", systemImage: "square.and.pencil")
        }
        .tint(Color.OF.accent)
    }
    .accessibilityAction(named: "Delete") {
        pendingDelete = log
    }
    .accessibilityAction(named: "Edit note") {
        editingLog = log
    }
```

(Two swipe actions on the trailing edge — Delete and Edit note. Delete
stays destructive-red; Edit note picks up `Color.OF.accent`. Swipe order
is right-to-left as declared — Delete reveals first, then Edit note.)

Add the persistence helper alongside the existing `deleteLog`:

```swift
extension HistoryView {
    nonisolated static func updateNote(_ log: FeelingLog,
                                       to newNote: String,
                                       in context: ModelContext) {
        log.note = newNote
        try? context.save()
    }
}
```

### `OpenFeelings/Views/HistoryView.swift` (or new file) — `NoteEditorSheet`

```swift
struct NoteEditorSheet: View {
    let log: FeelingLog
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                    .font(.OF.bodyEmphasis)
                    .foregroundStyle(Color.OF.text)
                Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)

                TextEditor(text: $draft)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                    .scrollContentBackground(.hidden)
                    .padding(CGFloat.OF.md)
                    .background(Color.OF.surface,
                                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card,
                                                     style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card,
                                         style: .continuous)
                            .stroke(Color.OF.divider, lineWidth: 1)
                    }
                    .frame(minHeight: 140)
                    .accessibilityLabel("Note")
            }
            .padding(.OF.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.OF.background)
            .navigationTitle("Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("noteEditor.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .accessibilityIdentifier("noteEditor.save")
                    .disabled(!hasChanges)
                }
            }
            .onAppear { draft = log.note }
        }
    }

    private var hasChanges: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
        != log.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

If `HistoryView.swift` is getting long, lift `NoteEditorSheet` into its
own file `OpenFeelings/Views/NoteEditorSheet.swift`. Either works.

## Tests

### `OpenFeelingsTests/HistoryNoteUpdateTests.swift` (new)

```swift
import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class HistoryNoteUpdateTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self, Intention.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func sampleLog(note: String = "") -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        return FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: 3,
            note: note
        )
    }

    func testUpdateNoteOverwritesPreviousValue() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "new", in: context)

        XCTAssertEqual(log.note, "new")
    }

    func testUpdateNotePersistsAcrossFetch() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "persisted", in: context)

        let fetched = try context.fetch(FetchDescriptor<FeelingLog>()).first
        XCTAssertEqual(fetched?.note, "persisted")
    }

    func testUpdateNoteToEmptyClearsTheNote() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "", in: context)

        XCTAssertEqual(log.note, "")
    }

    func testUpdateNoteDoesNotMutateOtherFields() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "new", in: context)

        XCTAssertEqual(log.coreID, "happy")
        XCTAssertEqual(log.intensity, 3)
    }
}
```

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

Expected: BUILD SUCCEEDED + 210 + 4 new = 214 passing tests.

### Manual verification on iPad (A16) iOS 26.0.1

With at least one saved check-in:

1. Open History. Swipe a card left → reveals **Edit note** and **Delete**.
2. Tap **Edit note** → modal sheet appears with the emotion path, date,
   and a TextEditor pre-filled with the current note.
3. Type. Save button enables.
4. Tap **Save** → sheet dismisses, card now shows the new note.
5. Reopen the editor. **Cancel** → sheet dismisses, note unchanged.
6. Cold-launch the app, reopen History — edited note persists.
7. VoiceOver — focus a card, open rotor → Actions. "Edit note" and
   "Delete" should both be present.
8. Drill into a filtered History (e.g. via Insights → By core). Edit a
   filtered card's note. Filter remains active after Save.

## Edge cases

- **Empty note.** Saving an empty (or all-whitespace) note clears the
  log's note. Card displays without a note row, same as a never-noted
  log. Acceptable.
- **HealthKit.** The original State of Mind sample is unchanged — we only
  touched SwiftData. This is the intended behavior (the HealthKit sample
  represents the moment of saving, not a current note state). Document
  in the commit message.
- **CloudKit conflict.** If two devices edit the same note concurrently,
  CloudKit resolves with last-writer-wins per field, same as every other
  SwiftData field. Acceptable; this is a single-user app.
- **Reduce-Motion.** Sheet present/dismiss respects the system
  Reduce-Motion preference automatically.

## Implementation order

1. Add `editingLog: FeelingLog?` state to `HistoryView`.
2. Add `.swipeActions` Edit-note button + `.accessibilityAction(named: "Edit note")`.
3. Add `extension HistoryView { static func updateNote(_:to:in:) }` alongside `deleteLog`.
4. Add `.sheet(item: $editingLog)` modifier to `HistoryView`'s body.
5. Add `NoteEditorSheet` (inline or new file).
6. Add the four unit tests.
7. Build + tests green.
8. Manual sim verification per checklist.
9. Single feature commit.

## Out of scope (and why)

- **Editing emotion or intensity:** the *moment* of a check-in is the
  source-of-truth claim. Letting the user edit it retroactively turns
  history into a malleable record; that's a different product (a
  journal, not a check-in log).
- **Rich text:** the rest of the app uses plain text notes; introducing
  markdown here without doing it elsewhere creates inconsistency.
- **Multi-device merge UI:** CloudKit's automatic last-writer-wins is
  sufficient. A merge prompt would be over-engineered for a
  single-user app.
- **HealthKit re-sync:** the HealthKit sample is intentionally
  point-in-time — editing notes later doesn't (and shouldn't) re-write
  it.
