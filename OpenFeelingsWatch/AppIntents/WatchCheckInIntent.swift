// OpenFeelingsWatch/AppIntents/WatchCheckInIntent.swift
import AppIntents

struct WatchCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a feeling"
    static let description = IntentDescription("Say how you're feeling and log it from your watch.")
    static let openAppWhenRun = false

    @Parameter(title: "How are you feeling?")
    var phrase: String

    enum Outcome {
        case send(WatchCheckInPayload, spoken: String)
        case handOff(spoken: String)
    }

    /// Pure, testable core: parse, then either build a payload to send or stash
    /// the utterance for the in-app hand-off. The WCSession send happens in perform().
    static func run(
        phrase: String,
        pending: PendingWatchEntryStore = PendingWatchEntryStore()
    ) async -> Outcome {
        let parsed = await FeelingParserProvider.current().parse(phrase)
        guard let core = parsed.core else {
            pending.stash(parsed.rawUtterance)
            return .handOff(spoken: "Let's finish this on your watch.")
        }
        let payload = WatchCheckInPayload(
            coreID: core.id,
            coreName: core.name,
            secondaryID: parsed.secondary?.id,
            secondaryName: parsed.secondary?.name,
            specificID: parsed.specific?.id,
            specificName: parsed.specific?.name,
            intensity: parsed.intensity,
            note: parsed.note.isEmpty ? nil : parsed.note
        )
        let title = parsed.specific?.name ?? parsed.secondary?.name ?? core.name
        let spoken: String
        if parsed.confidence == .high {
            let level = parsed.intensity.map { ", intensity \($0)" } ?? ""
            spoken = "Logged \(title)\(level)."
        } else {
            spoken = "Saved under \(title) — open the app to pin it down."
        }
        return .send(payload, spoken: spoken)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch await Self.run(phrase: phrase) {
        case .send(let payload, let spoken):
            WatchSessionClient.shared.send(payload)
            return .result(dialog: IntentDialog(stringLiteral: spoken))
        case .handOff(let spoken):
            // Open the watch app; CheckInRootView consumes the pending note.
            // VERIFY opensIntent against the watchOS AppIntents SDK (fallback:
            // drop the dialog and return .result(opensIntent: OpenWatchCheckInIntent())).
            return .result(opensIntent: OpenWatchCheckInIntent(), dialog: IntentDialog(stringLiteral: spoken))
        }
    }
}

/// Tiny app-opener the .none branch forwards to; opening the watch app triggers
/// CheckInRootView's pending-note consumption.
struct OpenWatchCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish a feeling on your watch"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult { .result() }
}
