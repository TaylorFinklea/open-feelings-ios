import Foundation
import CoreData
import CloudKit

/// Observable surface for the CloudKit private-database mirror powering
/// SwiftData. Watches `NSPersistentCloudKitContainer.eventChangedNotification`
/// and tracks the latest sync phase, error, and last-successful timestamp.
/// Surfaced in Settings → Privacy so silent sync failures aren't invisible
/// to users.
@MainActor
@Observable
final class CloudSyncMonitor {
    private(set) var state = CloudSyncState()

    init() {
        observe()
    }

    private func observe() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // We requested `.main` queue, so we *are* on the main thread.
            // Pull the Sendable scalars out of the (non-Sendable) Notification
            // here, then hop to MainActor without sending the notification.
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key]
                as? NSPersistentCloudKitContainer.Event else { return }
            let type = event.type
            let endDate = event.endDate
            let error = event.error
            MainActor.assumeIsolated {
                self?.apply(eventType: type, endDate: endDate, error: error)
            }
        }
    }

    /// Pure state transition exposed for unit tests. Production calls flow
    /// through `handle(notification:)` which extracts these three values from
    /// the CloudKit event before delegating here.
    func apply(eventType: NSPersistentCloudKitContainer.EventType,
               endDate: Date?,
               error: Error?) {
        if endDate == nil {
            // Event still in-flight.
            state.phase = (eventType == .import) ? .importing : .exporting
            return
        }
        // Event completed.
        state.phase = .idle
        if let error {
            state.lastError = Self.describe(error: error)
        } else {
            state.lastError = nil
            state.lastSuccessAt = endDate
        }
    }

    /// Turns a raw CloudKit error into a one-line, user-meaningful string.
    /// Exposed `static` for unit tests; called from `apply(...)` on real
    /// events. The default `Error.localizedDescription` for
    /// `CKError.partialFailure` is the famously useless "The operation
    /// couldn't be completed" — the actual cause lives in the per-record
    /// sub-errors. Dig those out first; fall back to friendly text for a
    /// handful of well-known top-level CKError codes; final fallback is the
    /// localized description.
    static func describe(error: Error) -> String {
        let nsError = error as NSError

        // Partial failure: pull the first sub-error's message. That's where
        // schema-mismatch / permission errors actually live.
        if let perRecord = nsError.userInfo[CKPartialErrorsByItemIDKey]
            as? [AnyHashable: Error],
           let firstSub = perRecord.values.first {
            let baseMsg = (firstSub as NSError).localizedDescription
            let n = perRecord.count
            return n > 1 ? "\(baseMsg) (and \(n - 1) more)" : baseMsg
        }

        // Friendly top-level CKError mappings for the common cases.
        if nsError.domain == CKErrorDomain {
            switch nsError.code {
            case CKError.Code.networkUnavailable.rawValue,
                 CKError.Code.networkFailure.rawValue:
                return "Network unavailable"
            case CKError.Code.notAuthenticated.rawValue:
                return "Not signed in to iCloud"
            case CKError.Code.quotaExceeded.rawValue:
                return "iCloud storage full"
            case CKError.Code.permissionFailure.rawValue:
                return "iCloud permission denied"
            case CKError.Code.serverRejectedRequest.rawValue:
                return "CloudKit rejected the request"
            default:
                break
            }
        }

        return nsError.localizedDescription
    }
}

/// Snapshot of the latest CloudKit sync state for SwiftUI consumers.
struct CloudSyncState: Equatable, Sendable {
    enum Phase: Sendable {
        case unknown      // No event observed yet — cold launch or CloudKit off
        case importing    // Pulling changes from CloudKit
        case exporting    // Pushing changes to CloudKit
        case idle         // Last event finished
    }

    var phase: Phase = .unknown
    var lastError: String?
    var lastSuccessAt: Date?

    /// User-facing one-line summary. Order of preference: error > success
    /// timestamp > phase. Used as the Settings subtitle.
    var statusLine: String {
        if let lastError {
            return "Sync error: \(lastError)"
        }
        if let lastSuccessAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relative = formatter.localizedString(for: lastSuccessAt, relativeTo: Date())
            return "Synced \(relative)"
        }
        switch phase {
        case .importing: return "Pulling latest…"
        case .exporting: return "Sending latest…"
        case .idle:      return "Synced"
        case .unknown:   return "Waiting for sync"
        }
    }

    /// Whether the row should render in an attention-grabbing color/glyph.
    var isFailing: Bool { lastError != nil }
}
