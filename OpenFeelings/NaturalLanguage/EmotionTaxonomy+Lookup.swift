// OpenFeelings/NaturalLanguage/EmotionTaxonomy+Lookup.swift
import Foundation

extension EmotionTaxonomy {
    /// A taxonomy location resolved from a name: always a core, with the
    /// secondary/specific path filled in when the name was a deeper node.
    struct ResolvedNode: Equatable {
        let core: EmotionCore
        let secondary: EmotionSecondary?
        let specific: EmotionSpecific?
    }

    /// Every core/secondary/specific name in the tree, for uniqueness checks.
    static var allNodeNames: [String] {
        cores.flatMap { core -> [String] in
            [core.name] + core.secondaries.flatMap { sec -> [String] in
                [sec.name] + sec.specifics.map { $0.name }
            }
        }
    }

    /// Case-insensitive exact-name resolution to the deepest node bearing
    /// that name. Returns nil when no node matches.
    static func node(named query: String) -> ResolvedNode? {
        let needle = query.lowercased()
        for core in cores {
            if core.name.lowercased() == needle {
                return ResolvedNode(core: core, secondary: nil, specific: nil)
            }
            for secondary in core.secondaries {
                if secondary.name.lowercased() == needle {
                    return ResolvedNode(core: core, secondary: secondary, specific: nil)
                }
                for specific in secondary.specifics where specific.name.lowercased() == needle {
                    return ResolvedNode(core: core, secondary: secondary, specific: specific)
                }
            }
        }
        return nil
    }
}
