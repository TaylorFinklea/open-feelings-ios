#if DEBUG
import Foundation
import SwiftData

/// Curated, privacy-safe demo data for App Store screenshots. Compiled only in
/// DEBUG and only seeded when the app is launched with `-screenshotMode`
/// (see `OpenFeelingsApp.makeModelContainer`). Never present in a Release build.
///
/// The dataset is a believable, gently-positive fortnight: all five emotion
/// cores represented (so the Insights charts read well), a set today + reflected
/// past intentions, a completed value sort with committed actions (one done, to
/// show the checkbox done-state), and two CBT thought records.
enum ScreenshotDemoSeeder {
    static func seed(into context: ModelContext) {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())

        func day(_ daysAgo: Int, hour: Double) -> Date {
            let base = cal.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? startOfToday
            return base.addingTimeInterval(hour * 3_600)
        }

        // MARK: Feeling logs — 15 across 14 days, all five cores.
        struct Seed {
            let daysAgo: Int; let hour: Double
            let core: String; let secondary: String?
            let intensity: Int; let note: String
            let body: [BodyRegion]; let sensations: [BodySensation]
            let triggers: [Trigger]; let coping: [Coping]
            let energy: Double; let valence: Double
        }
        let seeds: [Seed] = [
            Seed(daysAgo: 0, hour: 8.5, core: "happy", secondary: "peaceful", intensity: 3,
                 note: "Slow morning with coffee and a clear sky.",
                 body: [.chest], sensations: [.warm], triggers: [], coping: [.stillness, .breath], energy: 0.3, valence: 0.6),
            Seed(daysAgo: 0, hour: 20, core: "happy", secondary: "optimistic", intensity: 4,
                 note: "Looking forward to the weekend.",
                 body: [], sensations: [], triggers: [.anticipation], coping: [.walk], energy: 0.5, valence: 0.7),
            Seed(daysAgo: 1, hour: 13, core: "sad", secondary: "lonely", intensity: 2,
                 note: "A quiet afternoon — missed seeing friends.",
                 body: [.chest], sensations: [.heavy], triggers: [.boundaries], coping: [.journal], energy: -0.3, valence: -0.4),
            Seed(daysAgo: 2, hour: 8, core: "fearful", secondary: "anxious", intensity: 3,
                 note: "Big meeting on the calendar.",
                 body: [.stomach], sensations: [.fluttery], triggers: [.anticipation], coping: [.breath], energy: -0.2, valence: -0.2),
            Seed(daysAgo: 3, hour: 19, core: "happy", secondary: "proud", intensity: 4,
                 note: "Finished the thing I'd been putting off.",
                 body: [.chest], sensations: [.warm], triggers: [], coping: [.movement], energy: 0.6, valence: 0.8),
            Seed(daysAgo: 4, hour: 12, core: "angry", secondary: "frustrated", intensity: 3,
                 note: "Traffic and a missed call.",
                 body: [.shoulders], sensations: [.tight], triggers: [.conflict], coping: [.walk], energy: 0.1, valence: -0.5),
            Seed(daysAgo: 5, hour: 22, core: "sad", secondary: "hurt", intensity: 2,
                 note: "A comment stuck with me.",
                 body: [.throat], sensations: [.tight], triggers: [.conflict], coping: [.talk], energy: -0.4, valence: -0.5),
            Seed(daysAgo: 6, hour: 7.5, core: "happy", secondary: "excited", intensity: 4,
                 note: "Plans finally came together.",
                 body: [], sensations: [.buzzing], triggers: [.anticipation], coping: [.music], energy: 0.7, valence: 0.7),
            Seed(daysAgo: 7, hour: 18, core: "fearful", secondary: "insecure", intensity: 2,
                 note: "Second-guessing a decision.",
                 body: [.stomach], sensations: [.fluttery], triggers: [.memory], coping: [.journal], energy: -0.1, valence: -0.3),
            Seed(daysAgo: 8, hour: 10, core: "happy", secondary: "peaceful", intensity: 3,
                 note: "A long walk by the water.",
                 body: [.wholeBody], sensations: [.pleasant], triggers: [], coping: [.nature, .walk], energy: 0.4, valence: 0.6),
            Seed(daysAgo: 9, hour: 21, core: "disgusted", secondary: "disapproving", intensity: 2,
                 note: "Let down by the news.",
                 body: [.gut], sensations: [.heavy], triggers: [.news], coping: [.rest], energy: -0.2, valence: -0.4),
            Seed(daysAgo: 10, hour: 9, core: "happy", secondary: "optimistic", intensity: 3,
                 note: "New week, fresh start.",
                 body: [], sensations: [], triggers: [], coping: [.breath], energy: 0.3, valence: 0.5),
            Seed(daysAgo: 11, hour: 14, core: "sad", secondary: "vulnerable", intensity: 2,
                 note: "Opened up about something hard.",
                 body: [.chest], sensations: [.tight], triggers: [.boundaries], coping: [.talk], energy: -0.2, valence: -0.1),
            Seed(daysAgo: 12, hour: 8, core: "happy", secondary: "powerful", intensity: 4,
                 note: "Asked for what I needed.",
                 body: [.chest], sensations: [.warm], triggers: [.boundaries], coping: [.movement], energy: 0.6, valence: 0.7),
            Seed(daysAgo: 13, hour: 23, core: "fearful", secondary: "anxious", intensity: 3,
                 note: "Mind racing before sleep.",
                 body: [.head], sensations: [.buzzing], triggers: [.sleep], coping: [.breath], energy: -0.3, valence: -0.3),
        ]
        for s in seeds {
            guard let selection = EmotionTaxonomy.selection(
                coreID: s.core, secondaryID: s.secondary, specificID: nil) else { continue }
            context.insert(FeelingLog(
                createdAt: day(s.daysAgo, hour: s.hour),
                selection: selection,
                intensity: s.intensity,
                note: s.note,
                bodyRegions: s.body,
                bodySensations: s.sensations,
                triggers: s.triggers,
                coping: s.coping,
                moodEnergy: s.energy,
                moodValence: s.valence
            ))
        }

        // MARK: Intentions — today (unreflected) + two reflected look-backs.
        context.insert(Intention(date: startOfToday, text: "Notice one small good thing."))
        context.insert(Intention(date: cal.date(byAdding: .day, value: -2, to: startOfToday) ?? startOfToday,
                                 text: "Be patient with myself.",
                                 reflection: "I caught myself rushing and slowed down twice."))
        context.insert(Intention(date: cal.date(byAdding: .day, value: -5, to: startOfToday) ?? startOfToday,
                                 text: "Reach out to a friend.",
                                 reflection: "Texted Sam — we're getting lunch this week."))

        // MARK: Values — a completed sort + committed actions (one done).
        context.insert(ValueSort(
            createdAt: day(6, hour: 11),
            bucketAssignments: [
                "family": .veryImportant, "health": .veryImportant, "growth": .veryImportant,
                "honesty": .important, "creativity": .important, "adventure": .notForMe,
            ],
            rankedTop: ["family", "health", "growth", "honesty", "creativity"]
        ))
        context.insert(CommittedAction(
            createdAt: day(5, hour: 9), title: "Call mom this weekend",
            valueRef: "family", whatsHard: "I get busy and forget to slow down."))
        let walk = CommittedAction(
            createdAt: day(8, hour: 7), title: "Walk 20 minutes after lunch", valueRef: "health")
        walk.isDone = true
        walk.completedAt = day(1, hour: 13)
        walk.reflection = "Did it most days — it cleared my head."
        context.insert(walk)

        // MARK: Thought records — two CBT reframes.
        context.insert(ThoughtRecord(
            createdAt: day(2, hour: 9),
            situation: "A colleague didn't reply to my message.",
            automaticThought: "They're upset with me.",
            intensityBefore: 5,
            patterns: [.mindReading, .worstCase],
            balancedThought: "They're probably just busy. I'll gently follow up tomorrow.",
            intensityAfter: 2))
        context.insert(ThoughtRecord(
            createdAt: day(9, hour: 20),
            situation: "Made a small mistake at work.",
            automaticThought: "I always mess things up.",
            intensityBefore: 4,
            patterns: [.alwaysNever, .filterTheGood],
            balancedThought: "One mistake doesn't erase the things I do well.",
            intensityAfter: 2))

        try? context.save()
    }
}
#endif
