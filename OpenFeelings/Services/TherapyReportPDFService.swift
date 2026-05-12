import SwiftUI
import UIKit

/// Value-typed manifest of a single page in the PDF.
enum TherapyReportPage: Equatable {
    case cover
    case patterns
    case notable
    case entries(pageNumber: Int, totalPages: Int)
    case intentions

    var isEntries: Bool {
        if case .entries = self { return true }
        return false
    }
}

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

        let pageList = pages(for: report)
        let data = renderer.pdfData { ctx in
            for page in pageList {
                ctx.beginPage()
                let imageRenderer = ImageRenderer(
                    content: view(for: page, report: report)
                        .frame(width: pageSize.width, height: pageSize.height)
                )
                // PDF contexts use Cartesian (origin bottom-left); SwiftUI's
                // ImageRenderer draws in UIKit coords (origin top-left). Flip
                // the Y axis around the page height so content lands right-
                // side up. Save/restore so consecutive pages start clean.
                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: 0, y: pageSize.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                imageRenderer.render { _, render in
                    render(ctx.cgContext)
                }
                ctx.cgContext.restoreGState()
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename(for: report))
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Page composition

    static func pages(for report: TherapyReportData) -> [TherapyReportPage] {
        var pages: [TherapyReportPage] = [.cover, .patterns]

        switch report.detailLevel {
        case .patternsOnly:
            break

        case .patternsAndNotable:
            if !report.notableLogs.isEmpty {
                pages.append(.notable)
            }

        case .fullEntries:
            let totalPages = (report.allLogs.count + entriesPerPage - 1) / entriesPerPage
            for index in 0..<totalPages {
                pages.append(.entries(pageNumber: index + 1, totalPages: totalPages))
            }
        }

        if !report.intentions.isEmpty {
            pages.append(.intentions)
        }

        return pages
    }

    @ViewBuilder
    private static func view(for page: TherapyReportPage, report: TherapyReportData) -> some View {
        switch page {
        case .cover:
            TherapyCoverPage(report: report)
        case .patterns:
            TherapyPatternsPage(report: report)
        case .notable:
            TherapyEntriesPage(
                title: "Notable entries",
                logs: report.notableLogs,
                pageNumber: nil,
                totalPages: nil
            )
        case .entries(let pageNumber, let totalPages):
            let start = (pageNumber - 1) * entriesPerPage
            let end = min(start + entriesPerPage, report.allLogs.count)
            let chunk = Array(report.allLogs[start..<end])
            TherapyEntriesPage(
                title: "Check-ins",
                logs: chunk,
                pageNumber: pageNumber,
                totalPages: totalPages
            )
        case .intentions:
            TherapyIntentionsPage(summaries: report.intentions)
        }
    }

    private static func filename(for report: TherapyReportData) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: report.generatedAt)
        return "OpenFeelings-Period-Summary-\(dateString).pdf"
    }
}
