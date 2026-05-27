import Foundation

/// Pure value-type diff between two ranked-top value-ref arrays. Consumed
/// by `PastSortsSheet` (browse) and `SortComparisonView` (auto-compare
/// modal after re-sort). Display side resolves refs → display names via
/// `ValueRef.displayName(for:customs:)`.
///
/// Bucket assignments are intentionally not part of this delta — only
/// changes to the ranked top are user-facing in the history.
struct SortDelta: Equatable {
    /// Refs in `current` but not in `prior`. Sorted by their index in
    /// `current` ascending.
    let added: [String]

    /// Refs in `prior` but not in `current`. Sorted by their index in
    /// `prior` ascending.
    let removed: [String]

    /// Refs that exist in both `prior` and `current` at different
    /// indices. Sorted by `to` ascending. Unchanged refs (same index in
    /// both) are not included.
    let moved: [Move]

    struct Move: Equatable {
        let ref: String
        let from: Int
        let to: Int
    }

    static func compute(prior: [String]?, current: [String]) -> SortDelta {
        guard let prior, !prior.isEmpty else {
            return SortDelta(added: current, removed: [], moved: [])
        }

        let priorIndex = Dictionary(uniqueKeysWithValues:
            prior.enumerated().map { ($1, $0) }
        )
        let currentIndex = Dictionary(uniqueKeysWithValues:
            current.enumerated().map { ($1, $0) }
        )

        let added = current.enumerated().compactMap { idx, ref -> (Int, String)? in
            priorIndex[ref] == nil ? (idx, ref) : nil
        }
        .sorted { $0.0 < $1.0 }
        .map(\.1)

        let removed = prior.enumerated().compactMap { idx, ref -> (Int, String)? in
            currentIndex[ref] == nil ? (idx, ref) : nil
        }
        .sorted { $0.0 < $1.0 }
        .map(\.1)

        let moved = current.enumerated().compactMap { idx, ref -> Move? in
            guard let from = priorIndex[ref], from != idx else { return nil }
            return Move(ref: ref, from: from, to: idx)
        }
        .sorted { $0.to < $1.to }

        return SortDelta(added: added, removed: removed, moved: moved)
    }
}
