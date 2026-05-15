import Foundation
import SwiftData
import SwiftUI

/// In-flight state for one card-sort session. Held in memory by
/// `SortFlowView` and discarded on cancel. Only `finalize(into:)` writes
/// a row. Phase transitions are gated — `advancePhase()` refuses if the
/// current phase isn't complete.
@MainActor
@Observable
final class SortSession {
    enum Phase: Sendable {
        case bucketing
        case pickingFinalists
        case ranking
        case confirming
    }

    private(set) var phase: Phase = .bucketing

    /// Snapshot of the deck order at session start. The current card pointer
    /// `index` walks this array. Custom values added mid-flow are appended.
    private(set) var deck: [String]
    private(set) var index: Int = 0

    private(set) var assignments: [String: SortBucket] = [:]
    private(set) var history: [String] = []        // refs in bucket order, for undo
    private(set) var finalists: [String] = []
    private(set) var ranked: [String] = []

    static let finalistCap = 10

    init(curated: [ValueDefinition], custom: [CustomValue]) {
        let curatedRefs = curated.map(\.id)
        let customRefs = custom.map { ValueRef.makeCustomRef($0.id) }
        self.deck = curatedRefs + customRefs
    }

    var currentRef: String? {
        guard index < deck.count else { return nil }
        return deck[index]
    }

    var veryImportantPool: [String] {
        deck.filter { assignments[$0] == .veryImportant }
    }

    func bucket(_ ref: String, into bucket: SortBucket) {
        guard phase == .bucketing, currentRef == ref else { return }
        assignments[ref] = bucket
        history.append(ref)
        index += 1
    }

    @discardableResult
    func undoLastBucket() -> Bool {
        guard phase == .bucketing, let last = history.popLast() else { return false }
        assignments.removeValue(forKey: last)
        index = max(0, index - 1)
        return true
    }

    /// Append a new custom value to the remaining deck (only valid during bucketing).
    func appendCustom(_ ref: String) {
        guard phase == .bucketing else { return }
        deck.append(ref)
    }

    func toggleFinalist(_ ref: String) {
        guard phase == .pickingFinalists else { return }
        if let i = finalists.firstIndex(of: ref) {
            finalists.remove(at: i)
        } else if finalists.count < Self.finalistCap {
            finalists.append(ref)
        }
    }

    func reorderRanked(from source: IndexSet, to destination: Int) {
        guard phase == .ranking else { return }
        ranked.move(fromOffsets: source, toOffset: destination)
    }

    @discardableResult
    func advancePhase() -> Bool {
        switch phase {
        case .bucketing:
            guard index >= deck.count else { return false }
            phase = .pickingFinalists
            return true
        case .pickingFinalists:
            guard !finalists.isEmpty else { return false }
            ranked = finalists
            phase = .ranking
            return true
        case .ranking:
            guard !ranked.isEmpty else { return false }
            phase = .confirming
            return true
        case .confirming:
            return false
        }
    }

    /// Reset to a fresh bucketing pass while keeping the deck the same.
    /// Used by the empty-Very-important-pile fallback in FinalistsStepView.
    func restartBucketing() {
        phase = .bucketing
        index = 0
        assignments.removeAll()
        history.removeAll()
        finalists.removeAll()
        ranked.removeAll()
    }

    /// Write the finalized ValueSort row. No-op + returns nil if not in
    /// the confirming phase or the ranked list is empty.
    @discardableResult
    func finalize(into context: ModelContext) -> ValueSort? {
        guard phase == .confirming, !ranked.isEmpty else { return nil }
        let sort = ValueSort(
            createdAt: .now,
            bucketAssignments: assignments,
            rankedTop: ranked
        )
        context.insert(sort)
        return sort
    }
}
