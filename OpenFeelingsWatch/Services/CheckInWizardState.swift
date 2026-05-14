import Foundation
import Observation

/// Source of truth for an in-progress watch check-in. Holding wizard state in
/// an @Observable class instead of multiple @State properties on the root view
/// avoids a watchOS NavigationStack race where destination views resolved
/// before pending @State writes propagated — producing blank screens after
/// each push. Class properties are mutated in place so any subsequent read
/// sees the new value immediately.
@MainActor
@Observable
final class CheckInWizardState {
    var core: EmotionCore?
    var secondary: EmotionSecondary?
    var specific: EmotionSpecific?
    var intensity: Int = 3
    var bodyRegions: Set<BodyRegion> = []
    var bodySensations: Set<BodySensation> = []
    var note: String = ""
    var didSend: Bool = false

    var feelingPath: String {
        [core?.name, secondary?.name, specific?.name]
            .compactMap { $0 }
            .joined(separator: " › ")
    }

    var shouldShowSensations: Bool {
        !bodyRegions.isEmpty && !bodyRegions.contains(.nowhere)
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reset() {
        core = nil
        secondary = nil
        specific = nil
        intensity = 3
        bodyRegions = []
        bodySensations = []
        note = ""
        didSend = false
    }
}
