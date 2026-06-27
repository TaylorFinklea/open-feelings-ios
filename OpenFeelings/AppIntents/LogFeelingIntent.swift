// OpenFeelings/AppIntents/LogFeelingIntent.swift
import AppIntents
import SwiftData

struct LogFeelingIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a feeling"
    static let description = IntentDescription("Save how you're feeling in plain language.")
    // Default: do not open the app. The .none branch opens it via opensIntent.
    static let openAppWhenRun = false

    @Parameter(title: "How are you feeling?")
    var phrase: String

    /// Pure, testable core. Parses, and either saves a "siri" log or stashes
    /// the utterance for the in-app hand-off. Returns what happened + a line.
    enum Outcome: Equatable {
        case saved(spoken: String)
        case handedOff(spoken: String)
    }

    @MainActor
    static func run(
        phrase: String,
        context: ModelContext,
        healthEnabled: Bool,
        healthService: HealthService? = nil,
        pending: PendingQuickEntryStore = PendingQuickEntryStore()
    ) async -> Outcome {
        let parsed = await FeelingParserProvider.current().parse(phrase)
        guard parsed.core != nil else {
            pending.stash(parsed.rawUtterance)
            return .handedOff(spoken: "Let's finish this in the app.")
        }
        let draft = parsed.toDraft()
        guard let log = FeelingLogService.persist(
            draft: draft, captureSource: "siri", into: context, healthEnabled: healthEnabled
        ) else {
            // Defensive: a resolved core should always yield a complete selection.
            pending.stash(parsed.rawUtterance)
            return .handedOff(spoken: "Let's finish this in the app.")
        }
        if let healthService {
            await FeelingLogService.syncHealth(log, healthService: healthService, healthEnabled: healthEnabled, into: context)
        }
        let title = draft.selection?.title ?? log.emotionTitle
        let spoken: String
        if parsed.confidence == .high {
            let level = parsed.intensity.map { ", intensity \($0)" } ?? ""
            spoken = "Logged: \(title)\(level). Open the app to add more."
        } else {
            spoken = "Saved your note under \(title) — open the app to pin down the feeling."
        }
        return .saved(spoken: spoken)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(OpenFeelingsModelContainer.shared)
        let healthEnabled = UserDefaults.standard.bool(forKey: "healthEnabled")
        let outcome = await Self.run(
            phrase: phrase, context: context, healthEnabled: healthEnabled,
            healthService: HealthService()
        )
        switch outcome {
        case .saved(let spoken):
            return .result(dialog: IntentDialog(stringLiteral: spoken))
        case .handedOff(let spoken):
            // Open the app to QuickEntry (it consumes PendingQuickEntryStore on
            // foreground). VERIFY opensIntent against current AppIntents docs.
            return .result(opensIntent: OpenQuickEntryIntent(), dialog: IntentDialog(stringLiteral: spoken))
        }
    }
}

/// Tiny app-opening intent the .none branch forwards to. Opening the app lets
/// RootView consume the pending utterance and present QuickEntry pre-filled.
struct OpenQuickEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish a feeling in the app"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // No-op: opening the app triggers RootView's pending consumption.
        .result()
    }
}
