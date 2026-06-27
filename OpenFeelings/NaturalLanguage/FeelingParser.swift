// OpenFeelings/NaturalLanguage/FeelingParser.swift
import Foundation

/// Turns one natural-language utterance into a ParsedFeeling. Async so the
/// Phase 2 Foundation Models parser conforms without changing call sites.
protocol FeelingParser {
    func parse(_ text: String) async -> ParsedFeeling
}

/// Phase 1 deterministic engine — also the permanent fallback. Pure value
/// type, no actor isolation, so `await parse(...)` is callable from anywhere.
struct KeywordFeelingParser: FeelingParser {
    func parse(_ text: String) async -> ParsedFeeling {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()

        let (core, secondary, specific, confidence) = resolveEmotion(in: lower)
        let intensity = scanIntensity(in: lower)
        let note = cleanedNote(from: raw)

        return ParsedFeeling(
            core: core, secondary: secondary, specific: specific,
            intensity: intensity, note: note,
            confidence: confidence, rawUtterance: raw
        )
    }

    // MARK: Emotion

    private func resolveEmotion(in lower: String)
        -> (EmotionCore?, EmotionSecondary?, EmotionSpecific?, ParsedFeeling.Confidence) {
        var best: (EmotionTaxonomy.ResolvedNode, depth: Int, ParsedFeeling.Confidence)?

        // Rank by (trust, depth): a confident (high) match always beats a
        // low-confidence one, and depth only breaks ties within the same trust
        // tier. Without this, a strictly-deeper WEAK synonym (e.g. "calm" ->
        // Peaceful) would override a shallower HIGH core ("sad"), flipping the
        // recorded emotion and downgrading confidence on phrasing like
        // "sad but calm".
        func consider(_ node: EmotionTaxonomy.ResolvedNode, _ confidence: ParsedFeeling.Confidence) {
            let depth = node.specific != nil ? 3 : (node.secondary != nil ? 2 : 1)
            let trust = (confidence == .high) ? 1 : 0
            guard let current = best else {
                best = (node, depth, confidence)
                return
            }
            let currentTrust = (current.2 == .high) ? 1 : 0
            if trust > currentTrust || (trust == currentTrust && depth > current.depth) {
                best = (node, depth, confidence)
            }
        }

        // Exact node-name hits (highest trust). Scan all names; longest-first
        // so "nervous" beats a bare core mention.
        for name in EmotionTaxonomy.allNodeNames.sorted(by: { $0.count > $1.count }) {
            if containsWord(name.lowercased(), in: lower), let node = EmotionTaxonomy.node(named: name) {
                consider(node, .high)
            }
        }
        // Synonyms.
        for entry in FeelingSynonyms.entries {
            if containsWord(entry.phrase, in: lower), let node = EmotionTaxonomy.node(named: entry.targetName) {
                consider(node, entry.strength == .strong ? .high : .low)
            }
        }

        guard let best else { return (nil, nil, nil, .none) }
        return (best.0.core, best.0.secondary, best.0.specific, best.2)
    }

    /// Word/phrase containment on token boundaries so "mad" doesn't match
    /// "nomad". Multi-word phrases ("on edge") match as substrings.
    private func containsWord(_ needle: String, in haystack: String) -> Bool {
        if needle.contains(" ") { return haystack.contains(needle) }
        let tokens = haystack.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return tokens.contains(needle)
    }

    // MARK: Intensity

    private func scanIntensity(in lower: String) -> Int? {
        // Only accept a digit attached to an explicit rating cue: "n/5",
        // "n out of 5", or "intensity n". A bare digit elsewhere ("5 minutes
        // late", "3 deadlines") must NOT be read as the rating, and "0/5" must
        // not fall through to a stray trailing "5".
        if let m = lower.range(of: #"([1-5])\s*(?:/|out of)\s*5"#, options: .regularExpression),
           let v = Int(lower[m].prefix(1)) { return v }
        if let m = lower.range(of: #"intensity\s+([1-5])"#, options: .regularExpression),
           let d = lower[m].last, let v = Int(String(d)) { return v }

        // Word ladder — token-aware so "very" doesn't match "everyone" /
        // "recovery" and the cue isn't triggered by emotion-neutral words.
        // Multi-word/stem cues use phrase containment (distinctive enough).
        let tokens = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted))
        if tokens.contains("extremely") || lower.contains("unbearabl") { return 5 }
        if tokens.contains("really") || tokens.contains("very") { return 4 }
        if tokens.contains("slightly") || lower.contains("a little") || lower.contains("kind of") { return 2 }
        return nil
    }

    // MARK: Note

    private func cleanedNote(from raw: String) -> String {
        let prefixes = ["i feel like ", "i feel ", "i'm feeling ", "im feeling ", "feeling ", "i am ", "i'm ", "im "]
        let lower = raw.lowercased()
        for p in prefixes where lower.hasPrefix(p) {
            return String(raw.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
        }
        return raw
    }
}

/// The single composition point both surfaces call. Phase 1 returns the
/// keyword parser; Phase 2 returns the Foundation Models parser (with the
/// keyword parser as its fallback).
enum FeelingParserProvider {
    static func current() -> any FeelingParser {
        KeywordFeelingParser()
    }
}
