import SwiftUI
import UIKit

/// Renders a `TherapyReportData` to a multipage PDF using
/// `UIGraphicsPDFRenderer` + `ImageRenderer`. Text remains vector (search-
/// able), not rasterized.
@MainActor
enum TherapyReportPDFService {
    private static let pageSize = CGSize(width: 612, height: 792)   // US Letter
    private static let entriesPerPage = 5

    /// Writes the PDF to a temp URL and returns it. Filename includes the
    /// generation date so multiple exports don't collide.
    static func writePDF(_ report: TherapyReportData) throws -> URL {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Open Feelings",
            kCGPDFContextTitle as String: "Period Summary",
            kCGPDFContextSubject as String: "Self-reported emotion check-in summary",
        ]
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        let pages = makePages(for: report)
        let data = renderer.pdfData { ctx in
            for page in pages {
                ctx.beginPage()
                let imageRenderer = ImageRenderer(content: page.frame(width: pageSize.width,
                                                                      height: pageSize.height))
                imageRenderer.render { _, render in
                    render(ctx.cgContext)
                }
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename(for: report))
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Page composition

    private static func makePages(for report: TherapyReportData) -> [AnyView] {
        var pages: [AnyView] = [
            AnyView(TherapyCoverPage(report: report)),
            AnyView(TherapyPatternsPage(report: report)),
        ]

        switch report.detailLevel {
        case .patternsOnly:
            break

        case .patternsAndNotable:
            if !report.notableLogs.isEmpty {
                pages.append(AnyView(TherapyEntriesPage(
                    title: "Notable entries",
                    logs: report.notableLogs,
                    pageNumber: nil,
                    totalPages: nil
                )))
            }

        case .fullEntries:
            let chunks = stride(from: 0, to: report.allLogs.count, by: entriesPerPage).map { start in
                Array(report.allLogs[start..<min(start + entriesPerPage, report.allLogs.count)])
            }
            for (index, chunk) in chunks.enumerated() {
                pages.append(AnyView(TherapyEntriesPage(
                    title: "Check-ins",
                    logs: chunk,
                    pageNumber: index + 1,
                    totalPages: chunks.count
                )))
            }
        }

        if !report.intentions.isEmpty {
            pages.append(AnyView(TherapyIntentionsPage(summaries: report.intentions)))
        }

        return pages
    }

    private static func filename(for report: TherapyReportData) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: report.generatedAt)
        return "OpenFeelings-Period-Summary-\(dateString).pdf"
    }
}
