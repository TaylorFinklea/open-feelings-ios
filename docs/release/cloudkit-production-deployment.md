# CloudKit Production Deployment Runbook

A step-by-step checklist for promoting Open Feelings's CloudKit schema from
**Development** to **Production**. Run through this exactly once, before the
first App Store submission.

After production rollout, additive schema changes (new record types, new
fields) can be deployed by re-running the "Deploy Schema Changes" step. Field
removals and type changes are **not** supported in production — you'd have to
roll out a new container.

---

## Pre-flight

| Check | How to verify |
|---|---|
| Container ID is `iCloud.dev.finklea.openfeelings` | `OpenFeelings/OpenFeelings.entitlements` lists this exactly |
| `OpenFeelingsApp.swift` enables CloudKit only on device builds | Lines around the `ModelContainer` setup |
| Bundle ID is `dev.finklea.openfeelings` | `project.yml` `PRODUCT_BUNDLE_IDENTIFIER` |
| Apple Developer account is signed in to Xcode | Xcode → Settings → Accounts |
| Latest build runs on a real device (not simulator — sim has CloudKit disabled) | TestFlight or `xcodebuild -destination generic/platform=iOS` |

If any of these fail, fix before continuing — you can't undo a production
deploy.

---

## Schema reference

The app persists two SwiftData entities. CloudKit auto-derives record types
and field names from these, prefixed with `CD_`:

### `CD_FeelingLog`

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | Primary identifier |
| `createdAt` | `CD_createdAt` | Date | **Index for "Query"** |
| `coreID` | `CD_coreID` | String | Stable taxonomy key |
| `coreName` | `CD_coreName` | String | Display string at write time |
| `secondaryID` | `CD_secondaryID` | String | Optional path component |
| `secondaryName` | `CD_secondaryName` | String | Optional path component |
| `specificID` | `CD_specificID` | String | Optional path component |
| `specificName` | `CD_specificName` | String | Optional path component |
| `intensity` | `CD_intensity` | Int (optional) | 1–5 |
| `note` | `CD_note` | String | Free text |
| `healthSyncStatusRaw` | `CD_healthSyncStatusRaw` | String | Enum raw value |
| `bodyRegionsRaw` | `CD_bodyRegionsRaw` | String | Comma-joined IDs |
| `bodySensationsRaw` | `CD_bodySensationsRaw` | String | Comma-joined IDs |
| `contextPlacesRaw` | `CD_contextPlacesRaw` | String | Comma-joined IDs |
| `contextPeopleRaw` | `CD_contextPeopleRaw` | String | Comma-joined IDs |
| `triggersRaw` | `CD_triggersRaw` | String | Comma-joined IDs |
| `copingRaw` | `CD_copingRaw` | String | Comma-joined IDs |
| `moodEnergy` | `CD_moodEnergy` | Double (optional) | -1.0…1.0 |
| `moodValence` | `CD_moodValence` | Double (optional) | -1.0…1.0 |

### `CD_Intention`

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | Primary identifier |
| `date` | `CD_date` | Date | **Index for "Query"** — start-of-day |
| `text` | `CD_text` | String | One-line intention |
| `reflection` | `CD_reflection` | String | Empty string until reflected |

System fields (`recordName`, `createdTimestamp`, `modifiedTimestamp`,
`createdBy`, `modifiedBy`) are auto-managed by CloudKit.

---

## Steps

### 1. Run the app on a signed device build

This populates the Development schema with both record types. Without this,
there's nothing to deploy.

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -destination generic/platform=iOS -derivedDataPath DerivedData build
```

Then install on a real iPhone or iPad signed in to iCloud, save at least one
check-in *and* one intention with a reflection. This forces every field on
both record types to be exercised.

### 2. Open the CloudKit Console

Visit https://icloud.developer.apple.com → **CloudKit Database** →
container **`iCloud.dev.finklea.openfeelings`** → **Development**
environment.

Verify:

- Record type **`CD_FeelingLog`** exists with all 19 user fields above.
- Record type **`CD_Intention`** exists with all 4 user fields above.
- Each record type has a **`recordName`** queryable index by default.

### 3. Add queryable indexes

The app's predicates filter by `createdAt` (FeelingLog) and `date`
(Intention). For these to perform on real data, both fields need a
**Queryable** index in addition to the default `recordName` index.

In the CloudKit Console:

- `CD_FeelingLog` → Indexes → **Add Index** → field `CD_createdAt`,
  type **Queryable**.
- `CD_Intention` → Indexes → **Add Index** → field `CD_date`,
  type **Queryable**.

Without these, queries on a populated container will be slow or rejected on
the production environment.

### 4. Verify security roles

In the CloudKit Console for the **Development** environment:

- Each record type's **Security Roles** should be set so **`World`** has
  *no* permissions and **`Authenticated User`** has read/write within their
  own private database scope.
- The default for SwiftData-driven schemas usually matches this. Visit each
  record type and confirm.

The app does **not** use the public database, so no role tuning is needed
there.

### 5. Deploy schema changes to Production

Top-right of the CloudKit Console → **Deploy Schema Changes…**

Read the diff. The console will list every record type and field that's
about to be created in Production. Confirm you see:

- Two record types added: `CD_FeelingLog`, `CD_Intention`.
- Both indexes from step 3 listed.
- No deletions (this is a first deploy).

Click **Deploy**. Wait for the success banner.

### 6. Switch the console to Production and re-verify

Top-left environment toggle → **Production**.

Spot-check one field of each record type — they should be identical to
Development. If a field is missing, go back to step 1 and re-run the app on
a signed build to cover whatever case wasn't exercised.

### 7. Build a TestFlight / production app

Existing TestFlight builds (1–14) point at the same container ID and will
automatically use Production CloudKit when run from a non-development build.

Bump build number, archive, upload to App Store Connect:

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -destination 'generic/platform=iOS' \
  -archivePath build/Archive.xcarchive archive
xcodebuild -exportArchive -archivePath build/Archive.xcarchive \
  -exportPath build/Export-N \
  -exportOptionsPlist OpenFeelings/ExportOptions.plist
```

### 8. Two-device sync verification

This is the moment of truth. With **two iCloud-signed devices** signed in
to the same Apple ID:

1. On device A, install the new TestFlight build, save a check-in *and* set
   today's intention.
2. On device B (same Apple ID), install the same TestFlight build.
3. Wait 60–120 seconds for the initial sync.
4. Verify both records appear on device B.
5. On device B, edit the intention's reflection. After 60s, verify the edit
   appears on device A.
6. Toggle airplane mode on device A, save another check-in, then re-enable
   networking. Within ~60s the offline record should sync to device B.

If anything fails, capture screenshots and check the CloudKit Console
**Logs** tab → filter by container → look for permission/schema errors.

---

## Common gotchas

- **You can never remove a field from a Production record type.** Adding a
  new field is fine; renaming is fine *only if* you migrate the SwiftData
  property name in code. Removing requires a new container (effectively
  starting over with a new bundle ID's worth of users).
- **Optional vs default-valued.** SwiftData + CloudKit requires every
  property to either be optional or have a default. The schema is already
  built this way; don't break it by adding non-optional non-default
  properties later.
- **Large `note` text.** CloudKit's per-record string limit is 1MB.
  Free-text notes won't approach that, but mention it in feature work that
  could.
- **Migration.** First production users will start with no records; existing
  development-only data on developer devices will *not* migrate to
  Production. That's normal.
- **Account-changed scenario.** If a user signs out of iCloud and back in as
  a different Apple ID, the SwiftData store on-device persists but won't
  sync to the new account. This is expected — CloudKit's private DB is
  scoped to one Apple ID at a time.

---

## Rollback

There is no rollback for a Production deploy. The recoveries available are:

1. **Schema-only mistake** (e.g., missed an index): just re-deploy after
   adding it.
2. **Field added that shouldn't have been**: ignore the field in code.
   CloudKit retains it but the app no longer writes/reads it.
3. **Catastrophic mistake** (record type that should never have existed):
   the only "rollback" is creating a new container (`iCloud.dev.finklea.openfeelings.v2`)
   and deprecating the existing one. Existing user data does not migrate.

Treat the deploy step as one-way. Read the diff carefully before clicking
Deploy.

---

## When to revisit this runbook

- After adding any new SwiftData `@Model` class.
- After adding a new persisted property to an existing model.
- Before submitting the next major version to the App Store, in case the
  schema drifted during development.
