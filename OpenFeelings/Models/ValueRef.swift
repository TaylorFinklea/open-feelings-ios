import Foundation

/// Encodes a reference to a value as a string. `"family"` for curated
/// taxonomy entries, `"custom:<uuid>"` for user-added values. String form
/// is what gets persisted into `ValueSort` and `CommittedAction.valueRef`.
enum ValueRef {
    static let customPrefix = "custom:"

    static func isCustom(_ ref: String) -> Bool {
        ref.hasPrefix(customPrefix)
    }

    static func customUUID(from ref: String) -> UUID? {
        guard isCustom(ref) else { return nil }
        return UUID(uuidString: String(ref.dropFirst(customPrefix.count)))
    }

    static func makeCustomRef(_ id: UUID) -> String {
        customPrefix + id.uuidString
    }

    /// Resolve a ref to a user-facing name.
    /// Falls back to `"(removed value)"` if the referenced custom value
    /// is missing, and `"(unknown value)"` if a curated id is unknown.
    static func displayName(for ref: String, customs: [CustomValue]) -> String {
        if let uuid = customUUID(from: ref) {
            return customs.first { $0.id == uuid }?.name ?? "(removed value)"
        }
        return ValueTaxonomy.definition(id: ref)?.name ?? "(unknown value)"
    }
}
