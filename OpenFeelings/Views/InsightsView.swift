import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var allLogs: [FeelingLog]
    @AppStorage("notifyOnInsightsReady") private var notifyOnReady = false
    @AppStorage("insightsPeriod") private var periodRaw = InsightsPeriod.week.rawValue

    private var period: InsightsPeriod {
        InsightsPeriod(rawValue: periodRaw) ?? .week
    }

    private var dataset: InsightsDataset {
        InsightsDataset.build(logs: allLogs, period: period)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                heroHeader
                if allLogs.isEmpty {
                    comingSoonPreview
                } else {
                    periodPicker
                    if dataset.totalCount == 0 {
                        emptyForPeriod
                    } else {
                        chartCards
                    }
                }
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text("Insights")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text("Patterns")
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.lg)
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(InsightsPeriod.allCases) { p in
                Button {
                    withAnimation(.OF.quick) { periodRaw = p.rawValue }
                } label: {
                    Text(p.title)
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(period == p ? Color.OF.text : Color.OF.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            Group {
                                if period == p {
                                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip, style: .continuous)
                                        .fill(Color.OF.surface)
                                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.OF.accentSoft.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip + 4, style: .continuous))
    }

    // MARK: - Chart cards

    @ViewBuilder
    private var chartCards: some View {
        InsightsCheckInChart(dataset: dataset, period: period)
        InsightsTopFeelingsCard(dataset: dataset)
        if !dataset.topBodyRegions.isEmpty {
            InsightsBodyChart(dataset: dataset)
        }
        if !dataset.topTriggerCopingPairs.isEmpty {
            InsightsTriggersCopingList(dataset: dataset)
        }
        if !dataset.moodPoints.isEmpty {
            InsightsMoodScatter(dataset: dataset, scheme: colorScheme)
        }
    }

    // MARK: - Empty states

    private var emptyForPeriod: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("No check-ins this \(period == .week ? "week" : period == .month ? "month" : "period").")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Save a check-in or pick a longer window above.")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    private var comingSoonPreview: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFEmptyState(
                glyph: "chart.line.uptrend.xyaxis",
                title: "Your patterns, soon.",
                bodyText: "Save a few check-ins and Open Feelings will turn them into gentle weekly views."
            )
            OFButton(notifyOnReady ? "We'll let you know" : "Notify me when this is ready",
                     style: notifyOnReady ? .secondary : .primary) {
                notifyOnReady.toggle()
            }
        }
    }
}

// MARK: - Chart cards (private types)

private struct InsightsCheckInChart: View {
    let dataset: InsightsDataset
    let period: InsightsPeriod

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Check-ins").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                Text("\(dataset.totalCount) total in this \(period == .all ? "history" : period.title.lowercased())")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Chart(dataset.countsPerDay, id: \.day) { entry in
                    BarMark(
                        x: .value("Day", entry.day, unit: .day),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(Color.OF.accent)
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.OF.divider)
                        AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, dataset.countsPerDay.count / 6))) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.OF.caption)
                            .foregroundStyle(Color.OF.textMuted)
                    }
                }
            }
        }
    }
}

private struct InsightsTopFeelingsCard: View {
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Top feelings").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                if dataset.topFeelings.isEmpty {
                    Text("No emotions recorded yet.")
                        .font(.OF.body)
                        .foregroundStyle(Color.OF.textMuted)
                } else {
                    Chart(dataset.topFeelings, id: \.name) { feeling in
                        BarMark(
                            x: .value("Count", feeling.count),
                            y: .value("Name", feeling.name)
                        )
                        .foregroundStyle(Color.OF.accent)
                    }
                    .frame(height: CGFloat(dataset.topFeelings.count) * 32 + 24)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine().foregroundStyle(Color.OF.divider)
                            AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.text)
                        }
                    }
                }
            }
        }
    }
}

private struct InsightsBodyChart: View {
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Body").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                Text("Where the feelings live")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Chart(dataset.topBodyRegions, id: \.region) { entry in
                    BarMark(
                        x: .value("Count", entry.count),
                        y: .value("Region", entry.region.displayName)
                    )
                    .foregroundStyle(Color.OF.accent)
                }
                .frame(height: CGFloat(dataset.topBodyRegions.count) * 32 + 24)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.OF.divider)
                        AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.text)
                    }
                }
            }
        }
    }
}

private struct InsightsTriggersCopingList: View {
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Triggers & coping").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                Text("What led to what helped")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                VStack(alignment: .leading, spacing: .OF.xs) {
                    ForEach(Array(dataset.topTriggerCopingPairs.enumerated()), id: \.offset) { _, pair in
                        HStack {
                            Text("\(pair.trigger.displayName.localizedLowercase) → \(pair.coping.displayName.localizedLowercase)")
                                .font(.OF.body)
                                .foregroundStyle(Color.OF.text)
                            Spacer()
                            Text("\(pair.count)×")
                                .font(.OF.caption)
                                .foregroundStyle(Color.OF.textMuted)
                        }
                    }
                }
                .padding(.top, .OF.xs)
            }
        }
    }
}

private struct InsightsMoodScatter: View {
    let dataset: InsightsDataset
    let scheme: ColorScheme

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Mood scale").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                Text("Energy and valence over the period")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Chart {
                    // Center crosshair via two RuleMarks at 0
                    RuleMark(x: .value("Center", 0))
                        .foregroundStyle(Color.OF.divider)
                    RuleMark(y: .value("Center", 0))
                        .foregroundStyle(Color.OF.divider)
                    ForEach(Array(dataset.moodPoints.enumerated()), id: \.offset) { _, point in
                        PointMark(
                            x: .value("Energy", point.energy),
                            y: .value("Valence", point.valence)
                        )
                        .foregroundStyle(Color.OF.accent)
                        .symbolSize(60)
                    }
                }
                .frame(height: 220)
                .chartXScale(domain: -1...1)
                .chartYScale(domain: -1...1)
                .chartXAxis {
                    AxisMarks(values: [-1, 0, 1]) { value in
                        AxisGridLine().foregroundStyle(Color.OF.divider.opacity(0.5))
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(d == -1 ? "calm" : d == 0 ? "" : "active")
                                    .font(.OF.caption)
                                    .foregroundStyle(Color.OF.textMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [-1, 0, 1]) { value in
                        AxisGridLine().foregroundStyle(Color.OF.divider.opacity(0.5))
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(d == -1 ? "unpleasant" : d == 0 ? "" : "pleasant")
                                    .font(.OF.caption)
                                    .foregroundStyle(Color.OF.textMuted)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview { NavigationStack { InsightsView() } }
