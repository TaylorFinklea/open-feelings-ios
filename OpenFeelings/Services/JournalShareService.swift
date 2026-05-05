// OpenFeelings/Services/JournalShareService.swift
import Foundation
import UIKit

/// Builds URL-scheme handoffs to other journaling apps. Apple Journal accepts
/// share-sheet text (handled directly by `ShareLink`); this service handles
/// apps that surface via a custom URL scheme — currently Day One.
enum JournalShareService {
    /// Opens Day One with the entry pre-filled.
    /// Day One's URL scheme: `dayone://post?entry=<encoded>&starred=false&tags=...`
    /// Returns nil if the markdown can't be percent-encoded for the query.
    static func dayOneURL(forMarkdown markdown: String) -> URL? {
        guard let encoded = markdown.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "dayone://post?entry=\(encoded)&starred=false&tags=open-feelings")
    }

    /// True when Day One responds to its URL scheme. Requires `dayone` in
    /// `LSApplicationQueriesSchemes` in Info.plist; otherwise the system
    /// returns false even when Day One is installed.
    static var dayOneInstalled: Bool {
        guard let url = URL(string: "dayone://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
