import Foundation
import SwiftUI

struct EmotionCore: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let secondaries: [EmotionSecondary]
}

struct EmotionSecondary: Identifiable, Hashable {
    let id: String
    let name: String
    let specifics: [EmotionSpecific]
}

struct EmotionSpecific: Identifiable, Hashable {
    let id: String
    let name: String
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

    var pathTitle: String {
        [core.name, secondary?.name, specific?.name].compactMap { $0 }.joined(separator: " > ")
    }

    var isComplete: Bool {
        secondary != nil && specific != nil
    }
}

enum EmotionTaxonomy {
    static let cores: [EmotionCore] = [
        EmotionCore(
            id: "anger",
            name: "Anger",
            colorHex: "D94E41",
            secondaries: [
                EmotionSecondary(id: "irritated", name: "Irritated", specifics: [
                    EmotionSpecific(id: "annoyed", name: "Annoyed"),
                    EmotionSpecific(id: "impatient", name: "Impatient"),
                    EmotionSpecific(id: "bothered", name: "Bothered")
                ]),
                EmotionSecondary(id: "resentful", name: "Resentful", specifics: [
                    EmotionSpecific(id: "bitter", name: "Bitter"),
                    EmotionSpecific(id: "wronged", name: "Wronged"),
                    EmotionSpecific(id: "envious", name: "Envious")
                ]),
                EmotionSecondary(id: "threatened", name: "Threatened", specifics: [
                    EmotionSpecific(id: "defensive", name: "Defensive"),
                    EmotionSpecific(id: "pressured", name: "Pressured"),
                    EmotionSpecific(id: "suspicious", name: "Suspicious")
                ]),
                EmotionSecondary(id: "outraged", name: "Outraged", specifics: [
                    EmotionSpecific(id: "furious", name: "Furious"),
                    EmotionSpecific(id: "indignant", name: "Indignant"),
                    EmotionSpecific(id: "provoked", name: "Provoked")
                ])
            ]
        ),
        EmotionCore(
            id: "fear",
            name: "Fear",
            colorHex: "E18C3A",
            secondaries: [
                EmotionSecondary(id: "anxious", name: "Anxious", specifics: [
                    EmotionSpecific(id: "nervous", name: "Nervous"),
                    EmotionSpecific(id: "worried", name: "Worried"),
                    EmotionSpecific(id: "on-edge", name: "On edge")
                ]),
                EmotionSecondary(id: "insecure", name: "Insecure", specifics: [
                    EmotionSpecific(id: "unsure", name: "Unsure"),
                    EmotionSpecific(id: "exposed", name: "Exposed"),
                    EmotionSpecific(id: "not-enough", name: "Not enough")
                ]),
                EmotionSecondary(id: "helpless", name: "Helpless", specifics: [
                    EmotionSpecific(id: "trapped", name: "Trapped"),
                    EmotionSpecific(id: "powerless", name: "Powerless"),
                    EmotionSpecific(id: "lost", name: "Lost")
                ]),
                EmotionSecondary(id: "alarmed", name: "Alarmed", specifics: [
                    EmotionSpecific(id: "startled", name: "Startled"),
                    EmotionSpecific(id: "panicked", name: "Panicked"),
                    EmotionSpecific(id: "unsafe", name: "Unsafe")
                ])
            ]
        ),
        EmotionCore(
            id: "sadness",
            name: "Sadness",
            colorHex: "4D82D9",
            secondaries: [
                EmotionSecondary(id: "lonely", name: "Lonely", specifics: [
                    EmotionSpecific(id: "isolated", name: "Isolated"),
                    EmotionSpecific(id: "unseen", name: "Unseen"),
                    EmotionSpecific(id: "left-out", name: "Left out")
                ]),
                EmotionSecondary(id: "hurt", name: "Hurt", specifics: [
                    EmotionSpecific(id: "wounded", name: "Wounded"),
                    EmotionSpecific(id: "rejected", name: "Rejected"),
                    EmotionSpecific(id: "let-down", name: "Let down")
                ]),
                EmotionSecondary(id: "grief", name: "Grief", specifics: [
                    EmotionSpecific(id: "bereft", name: "Bereft"),
                    EmotionSpecific(id: "heavy", name: "Heavy"),
                    EmotionSpecific(id: "missing", name: "Missing")
                ]),
                EmotionSecondary(id: "low", name: "Low", specifics: [
                    EmotionSpecific(id: "tired", name: "Tired"),
                    EmotionSpecific(id: "empty", name: "Empty"),
                    EmotionSpecific(id: "discouraged", name: "Discouraged")
                ])
            ]
        ),
        EmotionCore(
            id: "shame",
            name: "Shame",
            colorHex: "8B6AC8",
            secondaries: [
                EmotionSecondary(id: "embarrassed", name: "Embarrassed", specifics: [
                    EmotionSpecific(id: "awkward", name: "Awkward"),
                    EmotionSpecific(id: "self-conscious", name: "Self-conscious"),
                    EmotionSpecific(id: "flustered", name: "Flustered")
                ]),
                EmotionSecondary(id: "guilty", name: "Guilty", specifics: [
                    EmotionSpecific(id: "regretful", name: "Regretful"),
                    EmotionSpecific(id: "remorseful", name: "Remorseful"),
                    EmotionSpecific(id: "responsible", name: "Responsible")
                ]),
                EmotionSecondary(id: "unworthy", name: "Unworthy", specifics: [
                    EmotionSpecific(id: "inadequate", name: "Inadequate"),
                    EmotionSpecific(id: "small", name: "Small"),
                    EmotionSpecific(id: "unlovable", name: "Unlovable")
                ]),
                EmotionSecondary(id: "vulnerable", name: "Vulnerable", specifics: [
                    EmotionSpecific(id: "open", name: "Open"),
                    EmotionSpecific(id: "tender", name: "Tender"),
                    EmotionSpecific(id: "fragile", name: "Fragile")
                ])
            ]
        ),
        EmotionCore(
            id: "disgust",
            name: "Disgust",
            colorHex: "78964B",
            secondaries: [
                EmotionSecondary(id: "aversion", name: "Aversion", specifics: [
                    EmotionSpecific(id: "repelled", name: "Repelled"),
                    EmotionSpecific(id: "uneasy", name: "Uneasy"),
                    EmotionSpecific(id: "turned-off", name: "Turned off")
                ]),
                EmotionSecondary(id: "contempt", name: "Contempt", specifics: [
                    EmotionSpecific(id: "dismissive", name: "Dismissive"),
                    EmotionSpecific(id: "superior", name: "Superior"),
                    EmotionSpecific(id: "scornful", name: "Scornful")
                ]),
                EmotionSecondary(id: "disappointed", name: "Disappointed", specifics: [
                    EmotionSpecific(id: "underwhelmed", name: "Underwhelmed"),
                    EmotionSpecific(id: "disillusioned", name: "Disillusioned"),
                    EmotionSpecific(id: "failed", name: "Failed")
                ]),
                EmotionSecondary(id: "distrust", name: "Distrust", specifics: [
                    EmotionSpecific(id: "skeptical", name: "Skeptical"),
                    EmotionSpecific(id: "guarded", name: "Guarded"),
                    EmotionSpecific(id: "betrayed", name: "Betrayed")
                ])
            ]
        ),
        EmotionCore(
            id: "joy",
            name: "Joy",
            colorHex: "E5C94A",
            secondaries: [
                EmotionSecondary(id: "happy", name: "Happy", specifics: [
                    EmotionSpecific(id: "cheerful", name: "Cheerful"),
                    EmotionSpecific(id: "playful", name: "Playful"),
                    EmotionSpecific(id: "light", name: "Light")
                ]),
                EmotionSecondary(id: "proud", name: "Proud", specifics: [
                    EmotionSpecific(id: "accomplished", name: "Accomplished"),
                    EmotionSpecific(id: "capable", name: "Capable"),
                    EmotionSpecific(id: "recognized", name: "Recognized")
                ]),
                EmotionSecondary(id: "grateful", name: "Grateful", specifics: [
                    EmotionSpecific(id: "thankful", name: "Thankful"),
                    EmotionSpecific(id: "appreciative", name: "Appreciative"),
                    EmotionSpecific(id: "blessed", name: "Blessed")
                ]),
                EmotionSecondary(id: "hopeful", name: "Hopeful", specifics: [
                    EmotionSpecific(id: "optimistic", name: "Optimistic"),
                    EmotionSpecific(id: "encouraged", name: "Encouraged"),
                    EmotionSpecific(id: "eager", name: "Eager")
                ])
            ]
        ),
        EmotionCore(
            id: "love",
            name: "Love",
            colorHex: "D55E94",
            secondaries: [
                EmotionSecondary(id: "connected", name: "Connected", specifics: [
                    EmotionSpecific(id: "close", name: "Close"),
                    EmotionSpecific(id: "accepted", name: "Accepted"),
                    EmotionSpecific(id: "belonging", name: "Belonging")
                ]),
                EmotionSecondary(id: "affectionate", name: "Affectionate", specifics: [
                    EmotionSpecific(id: "warm", name: "Warm"),
                    EmotionSpecific(id: "gentle", name: "Gentle"),
                    EmotionSpecific(id: "caring", name: "Caring")
                ]),
                EmotionSecondary(id: "compassionate", name: "Compassionate", specifics: [
                    EmotionSpecific(id: "kind", name: "Kind"),
                    EmotionSpecific(id: "moved", name: "Moved"),
                    EmotionSpecific(id: "sympathetic", name: "Sympathetic")
                ]),
                EmotionSecondary(id: "passionate", name: "Passionate", specifics: [
                    EmotionSpecific(id: "inspired", name: "Inspired"),
                    EmotionSpecific(id: "devoted", name: "Devoted"),
                    EmotionSpecific(id: "alive", name: "Alive")
                ])
            ]
        ),
        EmotionCore(
            id: "calm",
            name: "Calm",
            colorHex: "4AAE9B",
            secondaries: [
                EmotionSecondary(id: "peaceful", name: "Peaceful", specifics: [
                    EmotionSpecific(id: "settled", name: "Settled"),
                    EmotionSpecific(id: "quiet", name: "Quiet"),
                    EmotionSpecific(id: "at-ease", name: "At ease")
                ]),
                EmotionSecondary(id: "content", name: "Content", specifics: [
                    EmotionSpecific(id: "satisfied", name: "Satisfied"),
                    EmotionSpecific(id: "comfortable", name: "Comfortable"),
                    EmotionSpecific(id: "enough", name: "Enough")
                ]),
                EmotionSecondary(id: "present", name: "Present", specifics: [
                    EmotionSpecific(id: "grounded", name: "Grounded"),
                    EmotionSpecific(id: "clear", name: "Clear"),
                    EmotionSpecific(id: "mindful", name: "Mindful")
                ]),
                EmotionSecondary(id: "rested", name: "Rested", specifics: [
                    EmotionSpecific(id: "refreshed", name: "Refreshed"),
                    EmotionSpecific(id: "recharged", name: "Recharged"),
                    EmotionSpecific(id: "unhurried", name: "Unhurried")
                ])
            ]
        )
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
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
