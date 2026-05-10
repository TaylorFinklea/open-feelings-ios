import SwiftUI
import UIKit

/// Identifiable URL wrapper for `.sheet(item:)` share-sheet presentation.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Thin SwiftUI wrapper around `UIActivityViewController` for ad-hoc share
/// flows (export files, generated PDFs, etc.).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
