# Tip jar (in-app donations) — design

**Status:** approved (2026-05-28)
**Ships in:** a future build (TBD number at implementation time)
**Product decisions:** harness-deck `2026-05-27-app-store-launch-product-round`; `.docs/ai/decisions.md` 2026-05-28 entry.

## Why

Pre-App-Store-launch, Open Feelings needs a way for grateful users to support the project. The product round chose an **in-app tip jar via Apple IAP** — pure donation, unlocks nothing, everything stays free. Built as a reusable StoreKit module so it ports to the user's other projects.

## Constraints

- No ads, no analytics, no accounts, no servers, no third-party SDKs. StoreKit is first-party, so it's allowed.
- Tips unlock **nothing**. No feature gating, ever.
- Fire-and-forget: no persistence, no lifetime tracking, no gamification.

## Decisions locked

| Decision | Choice |
|---|---|
| Mechanism | Apple IAP via StoreKit 2 (async/await) |
| Product type | **Consumable** (repeatable tips; no restore) |
| Tiers | Soda `…tip.soda` $1.99 · Lunch `…tip.lunch` $4.99 · Dinner `…tip.dinner` $9.99 |
| Names + prices | From StoreKit `displayName` / `displayPrice` (App Store Connect, localized) — never hardcoded |
| Architecture | Protocol-abstracted generic client + `@Observable` app-specific service |
| Settings placement | Between `openSourceSection` and `aboutSection` |
| Thank-you | Gentle in-place row state change (✓ "Thank you" ~2s) + success haptic, reduce-motion aware |
| Cancel | Silent (no error) |
| Errors | Quiet inline; load failure shows "Couldn't load support options" + Retry |

Product IDs (full):
- `dev.finklea.openfeelings.tip.soda`
- `dev.finklea.openfeelings.tip.lunch`
- `dev.finklea.openfeelings.tip.dinner`

## Architecture

### Files to create

**`OpenFeelings/Services/StoreKit/StoreKitClient.swift`** — the reusable, app-agnostic layer.

```
enum StoreKitPurchaseOutcome: Sendable { case success, userCancelled, pending }

protocol StoreKitClienting: Sendable {
    func products(for ids: [String]) async throws -> [Product]
    func purchase(_ product: Product) async throws -> StoreKitPurchaseOutcome
    func observeTransactions() -> Task<Void, Never>
}

struct StoreKitClient: StoreKitClienting { /* real StoreKit 2 impl */ }
```

- `products(for:)` → `Product.products(for: ids)`.
- `purchase(_:)` → `product.purchase()`, switch the `PurchaseResult`. On `.success(let verification)`: if `.verified(let txn)`, `await txn.finish()` and return `.success`; if `.unverified`, still `finish()` and return `.success` (it's a tip — nothing to gate, and we don't want to swallow the user's money silently). `.userCancelled` → `.userCancelled`. `.pending` → `.pending`.
- `observeTransactions()` → a detached `Task` iterating `Transaction.updates`, finishing any unfinished transactions (covers interrupted/Ask-to-Buy purchases that resolve later). Knows nothing about which products are tips.
- Knows nothing about Open Feelings. This whole file lifts into another project unchanged.

**`OpenFeelings/Services/StoreKit/TipJarService.swift`** — app-specific, `@MainActor @Observable`.

```
@MainActor @Observable final class TipJarService {
    enum LoadState: Equatable { case idle, loading, loaded, failed }

    static let productIDs = [
        "dev.finklea.openfeelings.tip.soda",
        "dev.finklea.openfeelings.tip.lunch",
        "dev.finklea.openfeelings.tip.dinner",
    ]

    private(set) var tiers: [Product] = []        // sorted by price ascending
    private(set) var loadState: LoadState = .idle
    private(set) var thankedProductID: String?    // transient; drives in-place thank-you
    private(set) var purchaseFailed = false        // transient; drives quiet inline error

    private let client: StoreKitClienting
    init(client: StoreKitClienting = StoreKitClient())

    func load() async                              // loads + sorts tiers; sets loadState
    func tip(_ product: Product) async             // purchases; sets thankedProductID on success
    func clearThanks()                             // resets thankedProductID after the ~2s window
}
```

- `load()`: `loadState = .loading`; on success set `tiers = products.sorted { $0.price < $1.price }`, `loadState = .loaded`; on throw `loadState = .failed`.
- `tip(_:)`: call `client.purchase`. `.success` → set `thankedProductID = product.id`. `.userCancelled` / `.pending` → no-op (silent). thrown error → `purchaseFailed = true`.
- `clearThanks()` / a transient reset is driven by the view after a delay.

**`OpenFeelings/Views/Settings/SupportSection.swift`** — mirrors `BackupSection` exactly: a standalone `View` rendering `OFSectionHeader(title: "Support")` + a `Color.OF.surface` rounded container of rows, owning its own `@State private var tipJar = TipJarService()`.

- `.task { await tipJar.load() }`.
- `loadState == .loading/.idle` → a centered `ProgressView` row.
- `.failed` → an `OFListRow`-style row "Couldn't load support options" with a Retry button that re-runs `load()`.
- `.loaded` → `ForEach(tipJar.tiers, id: \.id)` rendering one tappable row per tier using the existing `OFListRow` pattern: leading SF Symbol, `tier.displayName` as title, trailing `tier.displayPrice`. On tap → `Task { await tipJar.tip(tier) }`.
- When `tipJar.thankedProductID == tier.id`: the trailing price swaps to a ✓ "Thank you" label; fire a success haptic (`UINotificationFeedbackGenerator().notificationOccurred(.success)`); after ~2s reset via `clearThanks()`. Wrap the swap in `withAnimation` gated on `accessibilityReduceMotion` (no animation when reduce-motion is on).
- A short `footerCaption`-style line under the rows: "Tips are a thank-you — every feature stays free." (mirrors the existing `footerCaption` helper's tone; SupportSection renders its own caption).

**`OpenFeelings/OpenFeelings.storekit`** — a StoreKit configuration file defining the 3 consumables (matching IDs, names, prices) so the flow runs in the simulator and in tests without App Store Connect. Wired into the `OpenFeelings` scheme's Run + Test options.

**`OpenFeelingsTests/TipJarServiceTests.swift`** — unit tests against a mock `StoreKitClienting`.

### Files to modify

**`OpenFeelings/Views/SettingsView.swift`** — insert `SupportSection()` in the `body`'s section list, between `openSourceSection` and `aboutSection`.

### No entitlements change

In-app purchase needs no `.entitlements` capability — it's automatic once the Paid Apps Agreement is active. `OpenFeelings.entitlements` is untouched.

## App Store Connect (mechanical, outside this codebase)

- Create 3 **consumable** IAP products with the IDs above; display names Soda / Lunch / Dinner; price points $1.99 / $4.99 / $9.99 (Apple's nearest tiers).
- Each product needs a display name, a one-line description, and a review screenshot.
- Paid Apps Agreement (banking + tax forms) must be active or the products won't load in production.
- Privacy nutrition label: consumable tips not linked to identity (no accounts) → still "Data Not Collected".

## Testing

`StoreKit`'s `Product` has no public initializer, so it can't be fabricated in a pure unit test. The clean way around this: load the three **real** `Product` values once from `OpenFeelings.storekit` via an `SKTestSession` (StoreKitTest framework) in `setUp()`, then inject them through a `MockStoreKitClient: StoreKitClienting`. The mock returns those real Products from `products(for:)` and returns a **canned `StoreKitPurchaseOutcome`** from `purchase(_:)` — the outcome enum is our own type and is freely mockable. This keeps the whole service state machine testable without touching the live App Store.

`TipJarServiceTests.swift` — ~6 tests:

1. `testLoadSuccessSortsTiersByPriceAscending` — mock returns the 3 Products unsorted; assert `tiers` is price-ascending.
2. `testLoadSuccessSetsLoadedState` — assert `loadState == .loaded`.
3. `testLoadFailureSetsFailedState` — mock `products` throws; assert `.failed`.
4. `testTipSuccessSetsThankedProductID` — mock `purchase` returns `.success`; assert `thankedProductID == product.id`.
5. `testTipCancelLeavesThankedProductIDNil` — mock returns `.userCancelled`; assert `thankedProductID == nil`, `purchaseFailed == false`.
6. `testTipErrorSetsPurchaseFailed` — mock `purchase` throws; assert `purchaseFailed == true`, `thankedProductID == nil`.

If `SKTestSession` setup proves unreliable on the CI sim, fall back to skipping tests 1 & 4 (the two needing real `Product` values) behind an availability/skip guard and keep 2/3/5/6 — but note that 5 & 6 still need *a* product to pass to `tip(_:)`, so they also depend on the `SKTestSession`-loaded Products. In practice all six share the one `setUp()` session; if it can't load, the whole suite skips with a clear message rather than failing.

No UI test in this spec — the Settings tip flow is low-risk and the StoreKit purchase sheet is system UI that XCUITest can't reliably drive. Manual on-device verification covers the happy path.

## Build sequence

1. `StoreKitClient.swift` (protocol + real impl + outcome enum). Compiles in isolation.
2. `OpenFeelings.storekit` config + scheme wiring.
3. `TipJarService.swift` + `TipJarServiceTests.swift` (TDD where the mock allows).
4. `SupportSection.swift`.
5. Wire `SupportSection()` into `SettingsView`.
6. Build + tests + manual sim smoke (the `.storekit` config makes the purchase sheet work in the sim).
7. Ship as the next build. App Store Connect IAP product setup happens in parallel (not a code dependency, but products won't load on real devices until configured + agreement active).

## Out of scope

- Restore purchases (consumables don't restore).
- Persistence / lifetime tip tracking (fire-and-forget).
- Receipt validation server (nothing to gate).
- Non-consumable "remove ads"-style products (there are no ads).
- Subscriptions.
