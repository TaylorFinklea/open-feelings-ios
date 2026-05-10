import SwiftUI

/// SwiftUI views, one per PDF page, designed to fit US Letter (612×792 pt).
/// Use system fonts and fixed sizes — the report is a clinical document, not
/// part of the warm-cream in-app design system.

private let pageWidth: CGFloat = 612
private let pageHeight: CGFloat = 792
private let pageMargin: CGFloat = 36   // 0.5"

private extension Color {
    static let reportText = Color(white: 0.10)
    static let reportMuted = Color(white: 0.40)
    static let reportRule = Color(white: 0.85)
}

private extension View {
    func reportPage() -> some View {
        self
            .frame(width: pageWidth, height: pageHeight, alignment: .topLeading)
            .background(Color.white)
    }

    func pagePadding() -> some View {
        self.padding(pageMargin)
    }
}

// MARK: - Cover

struct TherapyCoverPage: View {
    let report: TherapyReportData

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Open Feelings")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.reportMuted)
            Text("Period Summary")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.reportText)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 8) {
                row("Window", report.window.displayName)
                row("Detail level", report.detailLevel.displayName)
                row("Generated", report.generatedAt.formatted(date: .long, time: .shortened))
                row("Check-ins in window", "\(report.dataset.totalCount)")
                if report.dataset.currentStreak > 0 {
                    row("Current daily streak",
                        "\(report.dataset.currentStreak) day\(report.dataset.currentStreak == 1 ? "" : "s")")
                }
            }
            .font(.system(size: 13))

            Spacer()

            Text("This document summarizes self-reported emotion check-ins. It is not a clinical assessment.")
                .font(.system(size: 10))
                .foregroundStyle(Color.reportMuted)
        }
        .pagePadding()
        .reportPage()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 160, alignment: .leading)
                .foregroundStyle(Color.reportMuted)
            Text(value)
                .foregroundStyle(Color.reportText)
            Spacer()
        }
    }
}

// MARK: - Patterns

struct TherapyPatternsPage: View {
    let report: TherapyReportData

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("Patterns")

            if report.dataset.totalCount == 0 {
                Text("No check-ins captured in this window.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.reportMuted)
            } else {
                topCoresSection
                dayOfWeekSection
                intensitySection
                bodyRegionSection
            }

            Spacer()
        }
        .pagePadding()
        .reportPage()
    }

    private var topCoresSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Top emotion cores")
            ForEach(Array(report.dataset.byCore.prefix(5)), id: \.coreID) { entry in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: entry.colorHex))
                        .frame(width: 10, height: 10)
                    Text(entry.coreName)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.reportText)
                    Spacer()
                    Text("\(entry.count) check-in\(entry.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.reportMuted)
                }
            }
        }
    }

    private var dayOfWeekSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Day-of-week pattern")
            let maxCount = max(1, report.dataset.byDayOfWeek.map(\.count).max() ?? 1)
            ForEach(report.dataset.byDayOfWeek, id: \.weekday) { entry in
                HStack(spacing: 10) {
                    Text(entry.label)
                        .frame(width: 36, alignment: .leading)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.reportMuted)
                    Text(bar(for: entry.count, max: maxCount))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.reportText)
                    Spacer(minLength: 0)
                    Text("\(entry.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.reportMuted)
                }
            }
        }
    }

    private func bar(for count: Int, max: Int) -> String {
        let width = 24
        let filled = max == 0 ? 0 : Int((Double(count) / Double(max)) * Double(width))
        return String(repeating: "█", count: filled) + String(repeating: " ", count: width - filled)
    }

    @ViewBuilder
    private var intensitySection: some View {
        let trend = report.dataset.intensityTrend.compactMap(\.avgIntensity)
        if !trend.isEmpty {
            let avg = trend.reduce(0, +) / Double(trend.count)
            VStack(alignment: .leading, spacing: 6) {
                label("Average intensity")
                Text(String(format: "%.1f / 5", avg))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.reportText)
            }
        }
    }

    @ViewBuilder
    private var bodyRegionSection: some View {
        if let top = report.dataset.topBodyRegions.first {
            VStack(alignment: .leading, spacing: 6) {
                label("Most-felt body region")
                Text("\(top.region.displayName) (\(top.count) check-in\(top.count == 1 ? "" : "s"))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.reportText)
            }
        }
    }

    private func label(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.reportMuted)
            .padding(.top, 6)
    }
}

// MARK: - Entries (notable + full)

struct TherapyEntriesPage: View {
    let title: String
    let logs: [FeelingLog]
    let pageNumber: Int?
    let totalPages: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title)
            ForEach(logs, id: \.id) { log in
                EntryBlock(log: log)
            }
            Spacer()
            if let pageNumber, let totalPages {
                Text("Page \(pageNumber) of \(totalPages)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.reportMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .pagePadding()
        .reportPage()
    }
}

private struct EntryBlock: View {
    let log: FeelingLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.reportMuted)
                Spacer()
                if let intensity = log.intensity {
                    Text("intensity \(intensity)/5")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.reportMuted)
                }
            }
            Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.reportText)
            if !log.note.isEmpty {
                Text(truncated(log.note))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.reportText)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.reportRule).frame(height: 0.5)
        }
    }

    private func truncated(_ s: String) -> String {
        let maxLen = 360
        guard s.count > maxLen else { return s }
        let idx = s.index(s.startIndex, offsetBy: maxLen)
        return String(s[..<idx]) + "…"
    }
}

// MARK: - Intentions

struct TherapyIntentionsPage: View {
    let summaries: [IntentionSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Intentions in this window")
            ForEach(summaries, id: \.date) { item in
                IntentionBlock(summary: item)
            }
            Spacer()
        }
        .pagePadding()
        .reportPage()
    }
}

private struct IntentionBlock: View {
    let summary: IntentionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.reportMuted)
            Text(summary.text)
                .font(.system(size: 13))
                .foregroundStyle(Color.reportText)
            if !summary.topCoreNamesOnDay.isEmpty {
                Text("felt: \(summary.topCoreNamesOnDay.joined(separator: ", "))")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.reportMuted)
            }
            if summary.reflection.isEmpty {
                Text("no reflection yet")
                    .font(.system(size: 11).italic())
                    .foregroundStyle(Color.reportMuted)
            } else {
                Text("Reflection: \(summary.reflection)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.reportText)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.reportRule).frame(height: 0.5)
        }
    }
}

// MARK: - Helpers

private func sectionHeader(_ title: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.reportText)
        Rectangle().fill(Color.reportRule).frame(height: 0.5)
    }
}
