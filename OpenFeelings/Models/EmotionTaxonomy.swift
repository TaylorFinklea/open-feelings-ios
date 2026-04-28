import Foundation
import SwiftUI

// Taxonomy terms and arrangement are adapted from Open Emotion Wheel v1.1
// and licensed under CC BY-SA 4.0. See ATTRIBUTION.md and DATA-LICENSE.md.

struct EmotionCore: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let secondaries: [EmotionSecondary]

    var leafCount: Int {
        secondaries.reduce(0) { $0 + $1.leafCount }
    }
}

struct EmotionSecondary: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let specifics: [EmotionSpecific]

    var leafCount: Int {
        max(specifics.count, 1)
    }
}

struct EmotionSpecific: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
}

struct EmotionSelection: Identifiable, Hashable {
    let core: EmotionCore
    let secondary: EmotionSecondary?
    let specific: EmotionSpecific?

    var id: String {
        [core.id, secondary?.id, specific?.id].compactMap { $0 }.joined(separator: ".")
    }

    var title: String {
        specific?.name ?? secondary?.name ?? core.name
    }

    var colorHex: String {
        specific?.colorHex ?? secondary?.colorHex ?? core.colorHex
    }

    var pathTitle: String {
        [core.name, secondary?.name, specific?.name].compactMap { $0 }.joined(separator: " > ")
    }

    var isComplete: Bool {
        secondary != nil && specific != nil
    }
}

enum EmotionTaxonomy {
    static let sourceName = "Open Emotion Wheel v1.1"
    static let sourceURL = URL(string: "https://openemotionwheel.com/")!
    static let sourceAttribution = "Adapted from Open Emotion Wheel v1.1 by David Thorpe, openemotionwheel.com."
    static let sourceLicenseName = "CC BY-SA 4.0"
    static let sourceLicenseURL = URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!

    static let cores: [EmotionCore] = [
        core("Happy", colorHex: "F4D03F", secondaries: [
            secondary("Optimistic", colorHex: "F7DC6F", specificColorHex: "FCF3CF", specifics: [
                "Hopeful", "Inspired"
            ]),
            secondary("Peaceful", colorHex: "F7DC6F", specificColorHex: "FCF3CF", specifics: [
                "Loved", "Thankful"
            ]),
            secondary("Proud", colorHex: "F7DC6F", specificColorHex: "FCF3CF", specifics: [
                "Successful", "Confident"
            ]),
            secondary("Excited", colorHex: "F7DC6F", specificColorHex: "FCF3CF", specifics: [
                "Eager", "Energetic"
            ]),
            secondary("Powerful", colorHex: "F7DC6F", specificColorHex: "FCF3CF", specifics: [
                "Courageous", "Creative"
            ])
        ]),
        core("Sad", colorHex: "3498DB", secondaries: [
            secondary("Lonely", colorHex: "5DADE2", specificColorHex: "AED6F1", specifics: [
                "Isolated", "Abandoned"
            ]),
            secondary("Vulnerable", colorHex: "5DADE2", specificColorHex: "AED6F1", specifics: [
                "Victimised", "Fragile"
            ]),
            secondary("Despair", colorHex: "5DADE2", specificColorHex: "AED6F1", specifics: [
                "Grief", "Powerless"
            ]),
            secondary("Guilty", colorHex: "5DADE2", specificColorHex: "AED6F1", specifics: [
                "Remorseful", "Ashamed"
            ]),
            secondary("Hurt", colorHex: "5DADE2", specificColorHex: "AED6F1", specifics: [
                "Wounded", "Disappointed"
            ])
        ]),
        core("Angry", colorHex: "EC7063", secondaries: [
            secondary("Humiliated", colorHex: "F1948A", specificColorHex: "FADBD8", specifics: [
                "Disrespected", "Ridiculed"
            ]),
            secondary("Bitter", colorHex: "F1948A", specificColorHex: "FADBD8", specifics: [
                "Indignant", "Violated"
            ]),
            secondary("Frustrated", colorHex: "F1948A", specificColorHex: "FADBD8", specifics: [
                "Infuriated", "Annoyed"
            ]),
            secondary("Critical", colorHex: "F1948A", specificColorHex: "FADBD8", specifics: [
                "Sceptical", "Dismissive"
            ]),
            secondary("Distant", colorHex: "F1948A", specificColorHex: "FADBD8", specifics: [
                "Withdrawn", "Numb"
            ])
        ]),
        core("Fearful", colorHex: "AF7AC5", secondaries: [
            secondary("Anxious", colorHex: "C39BD3", specificColorHex: "E8DAEF", specifics: [
                "Overwhelmed", "Worried"
            ]),
            secondary("Insecure", colorHex: "C39BD3", specificColorHex: "E8DAEF", specifics: [
                "Inadequate", "Inferior"
            ]),
            secondary("Weak", colorHex: "C39BD3", specificColorHex: "E8DAEF", specifics: [
                "Worthless", "Insignificant"
            ]),
            secondary("Rejected", colorHex: "C39BD3", specificColorHex: "E8DAEF", specifics: [
                "Excluded", "Persecuted"
            ]),
            secondary("Threatened", colorHex: "C39BD3", specificColorHex: "E8DAEF", specifics: [
                "Nervous", "Exposed"
            ])
        ]),
        core("Disgusted", colorHex: "58D68D", secondaries: [
            secondary("Repelled", colorHex: "82E0AA", specificColorHex: "D5F5E3", specifics: [
                "Horrified", "Hesitant"
            ]),
            secondary("Awful", colorHex: "82E0AA", specificColorHex: "D5F5E3", specifics: [
                "Nauseated", "Detestable"
            ]),
            secondary("Disenchanted", colorHex: "82E0AA", specificColorHex: "D5F5E3", specifics: [
                "Appalled", "Revolted"
            ]),
            secondary("Disapproving", colorHex: "82E0AA", specificColorHex: "D5F5E3", specifics: [
                "Judgemental", "Embarrassed"
            ]),
            secondary("Startled", colorHex: "82E0AA", specificColorHex: "D5F5E3", specifics: [
                "Shocked", "Dismayed"
            ])
        ])
    ]

    static func selection(coreID: String, secondaryID: String?, specificID: String?) -> EmotionSelection? {
        guard let core = cores.first(where: { $0.id == coreID }) else {
            return nil
        }

        guard let secondaryID else {
            return EmotionSelection(core: core, secondary: nil, specific: nil)
        }

        guard let secondary = core.secondaries.first(where: { $0.id == secondaryID }) else {
            return EmotionSelection(core: core, secondary: nil, specific: nil)
        }

        guard let specificID else {
            return EmotionSelection(core: core, secondary: secondary, specific: nil)
        }

        let specific = secondary.specifics.first(where: { $0.id == specificID })
        return EmotionSelection(core: core, secondary: secondary, specific: specific)
    }

    private static func core(
        _ name: String,
        colorHex: String,
        secondaries: [EmotionSecondary]
    ) -> EmotionCore {
        EmotionCore(
            id: id(for: name),
            name: name,
            colorHex: colorHex,
            secondaries: secondaries
        )
    }

    private static func secondary(
        _ name: String,
        colorHex: String,
        specificColorHex: String,
        specifics: [String]
    ) -> EmotionSecondary {
        EmotionSecondary(
            id: id(for: name),
            name: name,
            colorHex: colorHex,
            specifics: specifics.map { specific($0, colorHex: specificColorHex) }
        )
    }

    private static func specific(_ name: String, colorHex: String) -> EmotionSpecific {
        EmotionSpecific(id: id(for: name), name: name, colorHex: colorHex)
    }

    private static func id(for name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        let scanner = Scanner(string: cleaned)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    static func readableText(onHex hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        let scanner = Scanner(string: cleaned)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.58 ? .black.opacity(0.82) : .white
    }
}
