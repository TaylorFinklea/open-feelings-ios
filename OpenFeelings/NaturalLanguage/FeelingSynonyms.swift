// OpenFeelings/NaturalLanguage/FeelingSynonyms.swift
//
// Original authored content. Licensed MIT (same as source code). This is a
// hand-authored mapping of everyday vernacular onto Open Feelings' own
// taxonomy node names — NOT a reproduction or adaptation of the Open Emotion
// Wheel taxonomy text/arrangement, and NOT derived from any third-party
// emotion lexicon. Do not import NRC EmoLex / WordNet-Affect / LIWC.
import Foundation

enum Strength { case strong, weak }

struct FeelingSynonym {
    let phrase: String     // lowercased vernacular
    let targetName: String // must equal a real EmotionTaxonomy node name
    let strength: Strength
}

enum FeelingSynonyms {
    static let entries: [FeelingSynonym] = [
        // Fearful
        .init(phrase: "anxious", targetName: "Anxious", strength: .strong),
        .init(phrase: "nervous", targetName: "Nervous", strength: .strong),
        .init(phrase: "on edge", targetName: "Anxious", strength: .strong),
        .init(phrase: "stressed", targetName: "Anxious", strength: .strong),
        .init(phrase: "scared", targetName: "Fearful", strength: .strong),
        .init(phrase: "afraid", targetName: "Fearful", strength: .strong),
        .init(phrase: "worried", targetName: "Worried", strength: .strong),
        .init(phrase: "overwhelmed", targetName: "Overwhelmed", strength: .strong),
        .init(phrase: "insecure", targetName: "Insecure", strength: .strong),
        // Sad
        .init(phrase: "sad", targetName: "Sad", strength: .strong),
        .init(phrase: "down", targetName: "Sad", strength: .strong),
        .init(phrase: "blue", targetName: "Sad", strength: .weak),
        .init(phrase: "low", targetName: "Sad", strength: .weak),
        .init(phrase: "lonely", targetName: "Lonely", strength: .strong),
        .init(phrase: "hurt", targetName: "Hurt", strength: .strong),
        .init(phrase: "disappointed", targetName: "Disappointed", strength: .strong),
        .init(phrase: "guilty", targetName: "Guilty", strength: .strong),
        .init(phrase: "ashamed", targetName: "Ashamed", strength: .strong),
        .init(phrase: "grief", targetName: "Grief", strength: .strong),
        // Angry
        .init(phrase: "angry", targetName: "Angry", strength: .strong),
        .init(phrase: "mad", targetName: "Angry", strength: .strong),
        .init(phrase: "pissed", targetName: "Angry", strength: .strong),
        .init(phrase: "furious", targetName: "Infuriated", strength: .strong),
        .init(phrase: "frustrated", targetName: "Frustrated", strength: .strong),
        .init(phrase: "annoyed", targetName: "Annoyed", strength: .strong),
        .init(phrase: "bitter", targetName: "Bitter", strength: .strong),
        .init(phrase: "humiliated", targetName: "Humiliated", strength: .strong),
        .init(phrase: "numb", targetName: "Numb", strength: .strong),
        // Happy
        .init(phrase: "happy", targetName: "Happy", strength: .strong),
        .init(phrase: "good", targetName: "Happy", strength: .weak),
        .init(phrase: "great", targetName: "Happy", strength: .weak),
        .init(phrase: "hopeful", targetName: "Hopeful", strength: .strong),
        .init(phrase: "grateful", targetName: "Thankful", strength: .strong),
        .init(phrase: "thankful", targetName: "Thankful", strength: .strong),
        .init(phrase: "loved", targetName: "Loved", strength: .strong),
        .init(phrase: "proud", targetName: "Proud", strength: .strong),
        .init(phrase: "confident", targetName: "Confident", strength: .strong),
        .init(phrase: "excited", targetName: "Excited", strength: .strong),
        .init(phrase: "energetic", targetName: "Energetic", strength: .strong),
        .init(phrase: "peaceful", targetName: "Peaceful", strength: .strong),
        .init(phrase: "calm", targetName: "Peaceful", strength: .weak),
        // Disgusted
        .init(phrase: "disgusted", targetName: "Disgusted", strength: .strong),
        .init(phrase: "grossed out", targetName: "Disgusted", strength: .strong),
        .init(phrase: "repelled", targetName: "Repelled", strength: .strong),
        .init(phrase: "horrified", targetName: "Horrified", strength: .strong),
        .init(phrase: "embarrassed", targetName: "Embarrassed", strength: .strong),
        .init(phrase: "shocked", targetName: "Shocked", strength: .strong),
        .init(phrase: "judgemental", targetName: "Judgemental", strength: .strong),
        // Broad / fuzzy fallbacks (weak)
        .init(phrase: "off", targetName: "Sad", strength: .weak),
        .init(phrase: "meh", targetName: "Sad", strength: .weak),
        .init(phrase: "tense", targetName: "Anxious", strength: .weak),
    ]
}
