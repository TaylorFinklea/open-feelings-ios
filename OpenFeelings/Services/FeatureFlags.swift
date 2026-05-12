import Foundation

/// Compile-time feature flags. Off-by-default for in-progress work that's
/// shipped behind a gate.
enum FeatureFlags {
    /// Body silhouette mode for the Check In wizard's Body step. Hidden in
    /// Settings and ignored at render time when off, so a stale AppStorage
    /// value from a prior build can't bleed through.
    static let silhouetteBodyView = false

    /// Face ID / passcode app lock. Off until we root-cause a freeze
    /// reported in build 17 — after the system biometric prompt dismissed,
    /// the app's `LockGateView` never advanced past the locked screen on a
    /// subsequent foreground. Setting this to `false` makes `LockGateView`
    /// transparent regardless of the user's `@AppStorage("appLockEnabled")`
    /// value, and hides the toggle in Settings so no new user can enable
    /// it. A stale stored `true` from a prior build is harmless.
    static let appLockEnabled = false
}
