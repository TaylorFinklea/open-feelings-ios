# CloudKit Production Deployment Runbook

A step-by-step checklist for promoting Open Feelings's CloudKit schema from
**Development** to **Production**. Run through this once before the first
App Store submission, then re-run the "Deploy Schema Changes" step after
each schema-altering release.

After production rollout, **additive** schema changes (new record types,
new fields, new indexes) can be re-deployed at any time. Field
**removals** and **type changes** are not supported in production — you'd
have to roll out a new container.

> ⚠️ **Likely silent-sync failure right now.** Builds 21–27 added new
> SwiftData @Model classes (`CustomBodyRegion`, `CustomValue`,
> `ValueSort`, `CommittedAction`, `UserBodyMap`) and new fields on
> `FeelingLog` (`customBodyRegionIDsRaw`, `captureSource`). If the
> Production schema only has the original `CD_FeelingLog` +
> `CD_Intention` from earlier work, the TestFlight build on a real device
> will store records locally but **silently fail** to mirror anything
> involving the new types/fields to iCloud. Run through this runbook
> before relying on two-device sync.

---

## Pre-flight

| Check | How to verify |
|---|---|
| Container ID is `iCloud.dev.finklea.openfeelings` | `OpenFeelings/OpenFeelings.entitlements` lists this exactly |
| `OpenFeelingsApp.swift` enables CloudKit only on device builds | `makeModelContainer()` — sim path uses `.none`, device path uses `.private(...)` |
| Bundle ID is `dev.finklea.openfeelings` | `project.yml` `PRODUCT_BUNDLE_IDENTIFIER` |
| Apple Developer account is signed in to Xcode | Xcode → Settings → Accounts |
| Latest build runs on a real device (not simulator — sim has CloudKit disabled by design) | TestFlight, or `xcodebuild -destination generic/platform=iOS` |

If any of these fail, fix before continuing — you can't undo a production
deploy.

---

## Schema reference (current as of build 27)

Open Feelings persists seven SwiftData `@Model` classes. CloudKit
auto-derives record types and field names from these, prefixed with
`CD_`. System fields (`recordName`, `createdTimestamp`,
`modifiedTimestamp`, `createdBy`, `modifiedBy`) are auto-managed by
CloudKit on every record type and are omitted from the tables below.

### `CD_FeelingLog`

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | Primary identifier; matches `recordName` |
| `createdAt` | `CD_createdAt` | Date | **Queryable index required** |
| `coreID` | `CD_coreID` | String | Stable taxonomy key |
| `coreName` | `CD_coreName` | String | Display string at write time |
| `secondaryID` | `CD_secondaryID` | String | Empty if stopped at core |
| `secondaryName` | `CD_secondaryName` | String | |
| `specificID` | `CD_specificID` | String | Empty if stopped at secondary |
| `specificName` | `CD_specificName` | String | |
| `intensity` | `CD_intensity` | Int (optional) | 1–5 |
| `note` | `CD_note` | String | Free text |
| `healthSyncStatusRaw` | `CD_healthSyncStatusRaw` | String | `HealthSyncStatus` raw value |
| `bodyRegionsRaw` | `CD_bodyRegionsRaw` | String | Comma-joined curated region IDs |
| `customBodyRegionIDsRaw` | `CD_customBodyRegionIDsRaw` | String | **NEW (build 27)** Comma-joined custom region UUIDs |
| `bodySensationsRaw` | `CD_bodySensationsRaw` | String | Comma-joined IDs |
| `contextPlacesRaw` | `CD_contextPlacesRaw` | String | Comma-joined IDs |
| `contextPeopleRaw` | `CD_contextPeopleRaw` | String | Comma-joined IDs |
| `triggersRaw` | `CD_triggersRaw` | String | Comma-joined IDs |
| `copingRaw` | `CD_copingRaw` | String | Comma-joined IDs |
| `moodEnergy` | `CD_moodEnergy` | Double (optional) | −1.0…1.0 |
| `moodValence` | `CD_moodValence` | Double (optional) | −1.0…1.0 |
| `captureSource` | `CD_captureSource` | String | **NEW (build 27)** `"phone"` or `"watch"` |

### `CD_Intention`

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | |
| `date` | `CD_date` | Date | **Queryable index required** — start-of-day |
| `text` | `CD_text` | String | One-line intention |
| `reflection` | `CD_reflection` | String | Empty string until reflected |

### `CD_CustomBodyRegion` — *new since original runbook*

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | Referenced by `FeelingLog.customBodyRegionIDsRaw` |
| `name` | `CD_name` | String | Trimmed display name |
| `createdAt` | `CD_createdAt` | Date | **Queryable index required** — drives stable chip order |

### `CD_CustomValue` — *new since original runbook*

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | Referenced via `"custom:<uuid>"` form |
| `name` | `CD_name` | String | Trimmed display name |
| `createdAt` | `CD_createdAt` | Date | **Queryable index required** — drives stable chip order |

### `CD_ValueSort` — *new since original runbook*

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | |
| `createdAt` | `CD_createdAt` | Date | **Queryable index required** — newest sort is active |
| `bucketAssignmentsRaw` | `CD_bucketAssignmentsRaw` | String | JSON-encoded `[String: SortBucket.rawValue]` |
| `rankedTopRaw` | `CD_rankedTopRaw` | String | JSON-encoded `[String]` |

### `CD_CommittedAction` — *new since original runbook*

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | |
| `createdAt` | `CD_createdAt` | Date | **Queryable index required** — sort by newest |
| `title` | `CD_title` | String | Trimmed |
| `valueRef` | `CD_valueRef` | String | `"family"` or `"custom:<uuid>"` |
| `whatsHard` | `CD_whatsHard` | String | Empty if not provided |
| `isDone` | `CD_isDone` | Int64 | Bool encoded as Int64 by CloudKit |
| `completedAt` | `CD_completedAt` | Date (optional) | |
| `reflection` | `CD_reflection` | String | Filled after marking done |

### `CD_UserBodyMap` — *new since original runbook*

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `entriesRaw` | `CD_entriesRaw` | String | JSON-encoded `[UserBodyMapEntry]` |

No `id` field — singleton-record pattern (one record per private DB).
`recordName` provides the only identity. No queryable indexes needed.

---

## Steps

### 1. Run the app on a signed device build to populate Development schema

This forces SwiftData to declare every record type and field on the
Development environment. Without this there is nothing to deploy.

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -destination 'generic/platform=iOS' -derivedDataPath DerivedData build
```

Install on a real iPhone or iPad signed in to iCloud, then exercise every
record type at least once:

- **FeelingLog**: save a check-in with intensity, a body region (curated
  *and* a custom), a trigger, a coping strategy, mood-scale values, and a
  note. Save another check-in from the paired Apple Watch (this writes
  `captureSource = "watch"`).
- **Intention**: set today's intention, then add a reflection on a
  previous day's intention.
- **CustomBodyRegion**: add a custom body region in Settings → Body map.
- **CustomValue**: start a value sort, add a custom value during
  bucketing.
- **ValueSort**: complete a sort (bucket → finalists → rank → confirm).
- **CommittedAction**: create a committed action, mark it done, write a
  reflection.
- **UserBodyMap**: override at least one body→core mapping in Settings →
  Body map.

### 2. Open the CloudKit Console and verify the Development schema

Visit <https://icloud.developer.apple.com> → **CloudKit Database** →
container **`iCloud.dev.finklea.openfeelings`** → **Development**
environment.

Verify all seven record types exist with the fields listed above:
`CD_FeelingLog`, `CD_Intention`, `CD_CustomBodyRegion`, `CD_CustomValue`,
`CD_ValueSort`, `CD_CommittedAction`, `CD_UserBodyMap`.

If any field is missing on `CD_FeelingLog`, the most likely cause is that
your step 1 check-in didn't exercise it (e.g., no watch entry → no
`CD_captureSource`). Save another check-in covering the missing case and
refresh.

### 3. Add queryable indexes

For each `@Query(sort:)` in the app, the sort field needs a **Queryable**
index. Default `recordName` index is auto-created and is enough for
predicate-by-id lookups.

In the CloudKit Console, on each record type → **Indexes** → **Add
Index**:

| Record type | Field | Index type |
|---|---|---|
| `CD_FeelingLog` | `CD_createdAt` | Queryable |
| `CD_Intention` | `CD_date` | Queryable |
| `CD_CustomBodyRegion` | `CD_createdAt` | Queryable |
| `CD_CustomValue` | `CD_createdAt` | Queryable |
| `CD_ValueSort` | `CD_createdAt` | Queryable |
| `CD_CommittedAction` | `CD_createdAt` | Queryable |

`CD_UserBodyMap` doesn't need an index — it's a singleton fetched by
`recordName`.

### 4. Verify security roles

For the Development environment, on each record type → **Security
Roles**:

- **`World`** has *no* permissions.
- **`Authenticated User`** has read/write within their own private
  database scope.

SwiftData-driven schemas usually come out of the box with this. Confirm
on every record type.

The app uses only the **private** database. The **public** and **shared**
databases need no role tuning.

### 5. Deploy schema changes to Production

Top-right of the CloudKit Console → **Deploy Schema Changes…**

Read the diff. The console lists every record type and field about to be
created or modified in Production. Confirm:

- **First deploy**: seven record types added, all fields listed above,
  six queryable indexes from step 3.
- **Subsequent deploy** (this is one): only the *new* types and the *new*
  fields/indexes should appear in the diff. If you see deletions, stop —
  see "Common gotchas" below.

Click **Deploy**. Wait for the success banner.

### 6. Switch the console to Production and re-verify

Top-left environment toggle → **Production**.

Spot-check one field of each record type — they should be identical to
Development. If a field is missing, go back to step 1 and re-run the app
on a signed build to cover whatever case wasn't exercised, then re-deploy.

### 7. Build a TestFlight / production app

If you're already on TestFlight, the current build automatically points
at Production CloudKit (TestFlight + App Store distribution forces the
Production environment regardless of the `aps-environment` entitlement).

If you need a fresh build:

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -destination 'generic/platform=iOS' \
  -archivePath build/Archive.xcarchive archive
xcodebuild -exportArchive -archivePath build/Archive.xcarchive \
  -exportPath build/Export-N \
  -exportOptionsPlist OpenFeelings/ExportOptions.plist \
  -authenticationKeyPath ~/.appstoreconnect/AuthKey_J79935N6P6.p8 \
  -authenticationKeyID J79935N6P6 \
  -authenticationKeyIssuerID fe27785a-1413-46ff-bd82-111de0da024f
```

### 8. Two-device sync verification

This is the moment of truth. With **two iCloud-signed devices** on the
same Apple ID:

1. On device A, install the new TestFlight build. Cover every record
   type at least once (same coverage as step 1).
2. On device B (same Apple ID), install the same TestFlight build.
3. Wait 60–120 seconds for the initial sync.
4. Verify each new record from device A appears on device B (check-ins,
   intentions, custom regions, custom values, the latest value sort, the
   committed actions list, body-map overrides).
5. On device B, edit a committed action's reflection and mark another
   action done. Within ~60s, verify both edits appear on device A.
6. Toggle airplane mode on device A, save another check-in, then
   re-enable networking. Within ~60s the offline record should sync to
   device B.

If anything fails, capture screenshots and check the CloudKit Console
**Logs** tab → filter by container → look for permission/schema errors.

---

## Common gotchas

- **You can never remove a field from a Production record type.** Adding
  a new field is fine; renaming is fine *only if* you migrate the
  SwiftData property name in code. Removing requires a new container
  (effectively starting over with a new bundle-ID's worth of users).
- **Field type changes are also irreversible.** Don't change a field
  from `String` to anything else after deploy; rename it (CloudKit treats
  the renamed property as a new field) and migrate code.
- **Bool fields land as `Int64`.** `CommittedAction.isDone` shows up as
  `Int64` in the console because CloudKit lacks a Bool primitive. Don't
  panic — SwiftData translates back to `Bool` on read.
- **Optional vs default-valued.** SwiftData + CloudKit requires every
  property to either be optional or have a default. The current schema
  is built this way; don't break it by adding non-optional non-default
  properties later.
- **Large `note` text.** CloudKit's per-record string limit is 1MB.
  Free-text notes won't approach that, but mention it in feature work
  that could.
- **First production users start empty.** Existing development-only data
  on developer devices will *not* migrate to Production. That's normal.
- **Account-changed scenario.** If a user signs out of iCloud and back
  in as a different Apple ID, the SwiftData store on-device persists but
  won't sync to the new account. This is expected — CloudKit's private
  DB is scoped to one Apple ID at a time.
- **Singleton records (`CD_UserBodyMap`).** First write creates the
  record; subsequent writes update it. Two devices writing concurrently
  resolves on a last-write-wins basis. Not perfect for body-map
  overrides, but acceptable because conflict windows are very rare for
  Settings-only data.

---

## Rollback

There is no rollback for a Production deploy. Recoveries available:

1. **Schema-only mistake** (e.g., missed an index): re-deploy after
   adding it.
2. **Field added that shouldn't have been**: ignore it in code. CloudKit
   retains the field; the app no longer writes/reads it.
3. **Catastrophic mistake** (record type that should never have existed,
   or a wrong field type): the only "rollback" is creating a new
   container (`iCloud.dev.finklea.openfeelings.v2`) and deprecating the
   existing one. Existing user data does not migrate.

Treat the deploy step as one-way. Read the diff carefully before
clicking Deploy.

---

## When to revisit this runbook

- After adding any new SwiftData `@Model` class.
- After adding a new persisted property to an existing model.
- Before submitting the next major version to the App Store, in case the
  schema drifted during development.
