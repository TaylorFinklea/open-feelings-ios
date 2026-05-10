import Foundation

/// Compile-time feature flags. Off-by-default for in-progress work that's
/// shipped behind a gate.
enum FeatureFlags {
    /// Body silhouette mode for the Check In wizard's Body step. Hidden in
    /// Settings and ignored at render time when off, so a stale AppStorage
    /// value from a prior build can't bleed through.
    static let silhouetteBodyView = false
}
