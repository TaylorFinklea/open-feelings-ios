import Accessibility
import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var allLogs: [FeelingLog]
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
                    emptyOverall
                } else {
                    InsightsHeroCard(dataset: dataset, period: period)
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
        if !dataset.byCore.isEmpty {
            InsightsByCoreCard(dataset: dataset)
        }
        InsightsTopFeelingsCard(dataset: dataset)
        if dataset.byDayOfWeek.contains(where: { $0.count > 0 }) {
            InsightsByDayOfWeekCard(dataset: dataset)
        }
        if dataset.intensityTrend.contains(where: { $0.avgIntensity != nil })
           && dataset.intensityTrend.count <= 90 {
            InsightsIntensityTrendCard(dataset: dataset)
        }
        if !dataset.topBodyRegions.isEmpty {
            InsightsBodyChart(dataset: dataset)
        }
        if !dataset.topTriggerCopingPairs.isEmpty {
            InsightsTriggersCopingList(dataset: dataset)
        }
        if !dataset.moodPoints.isEmpty {
            InsightsMoodScatter(dataset: dataset)
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

    private var emptyOverall: some View {
        OFEmptyState(
            glyph: "chart.line.uptrend.xyaxis",
            title: "No patterns yet",
            bodyText: "Save a few check-ins and they'll cluster into trends here."
        )
    }
}

// MARK: - Hero card

private struct InsightsHeroCard: View {
    let dataset: InsightsDataset
    let period: InsightsPeriod

    var body: some View {
        OFCard {
            HStack(alignment: .top, spacing: .OF.lg) {
                stat(value: "\(dataset.totalCount)",
                     label: "this \(period.title.lowercased())")
                Divider().frame(height: 36).background(Color.OF.divider)
                stat(value: deltaString,
                     label: "vs prior \(period.title.lowercased())")
                Divider().frame(height: 36).background(Color.OF.divider)
                stat(value: "\(dataset.currentStreak)",
                     label: "day streak")
            }
        }
    }

    private var deltaString: String {
        if period == .all { return "—" }
        let d = dataset.totalCount - dataset.previousPeriodCount
        return d > 0 ? "+\(d)" : "\(d)"
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.OF.headline).foregroundStyle(Color.OF.text)
            Text(label).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .accessibilityLabel(entry.day.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue(checkInCountPhrase(entry.count))
                }
                .accessibilityLabel(InsightsSummary.checkInsPerDay(totalCount: dataset.totalCount,
                                                                    dayCount: dataset.countsPerDay.count))
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

private struct InsightsByCoreCard: View {
    @Environment(AppNavigation.self) private var navigation
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("By core").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                    Spacer()
                    Text("Tap a bar to filter History")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
                Text("Where the feelings cluster")
                    .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Chart(dataset.byCore, id: \.coreID) { entry in
                    BarMark(
                        x: .value("Count", entry.count),
                        y: .value("Core", entry.coreName)
                    )
                    .foregroundStyle(Color.OF.core(entry.coreID))
                    .accessibilityLabel(entry.coreName)
                    .accessibilityValue(checkInCountPhrase(entry.count))
                }
                .accessibilityLabel(InsightsSummary.byCore(dataset.byCore))
                .accessibilityChartDescriptor(ByCoreChartAX(dataset: dataset))
                .frame(height: CGFloat(dataset.byCore.count) * 32 + 24)
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
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleTap(at: location, proxy: proxy, geo: geo)
                            }
                    }
                }
            }
        }
    }

    private func handleTap(at location: CGPoint,
                           proxy: ChartProxy,
                           geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotRect = geo[plotFrame]
        let relativeY = location.y - plotRect.minY
        guard let coreName: String = proxy.value(atY: relativeY) else { return }
        guard let core = EmotionTaxonomy.cores.first(where: { $0.name == coreName }) else { return }
        navigation.drillIntoHistory(filter: .coreID(core.id))
    }
}

private struct ByCoreChartAX: AXChartDescriptorRepresentable {
    let dataset: InsightsDataset

    func makeChartDescriptor() -> AXChartDescriptor {
        InsightsChartDescriptor.barCategorical(
            title: "By core",
            items: dataset.byCore.map { (category: $0.coreName, count: $0.count) }
        )
    }
}

private struct InsightsTopFeelingsCard: View {
    @Environment(AppNavigation.self) private var navigation
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Top feelings").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                    Spacer()
                    if !dataset.topFeelings.isEmpty {
                        Text("Tap a bar to filter History")
                            .font(.OF.caption)
                            .foregroundStyle(Color.OF.textMuted)
                    }
                }
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
                        .foregroundStyle(Color.OF.core(feeling.coreID))
                        .accessibilityLabel(feeling.name)
                        .accessibilityValue(checkInCountPhrase(feeling.count))
                    }
                    .accessibilityLabel(InsightsSummary.topFeelings(dataset.topFeelings))
                    .accessibilityChartDescriptor(TopFeelingsChartAX(dataset: dataset))
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    handleTap(at: location, proxy: proxy, geo: geo)
                                }
                        }
                    }
                }
            }
        }
    }

    private func handleTap(at location: CGPoint,
                           proxy: ChartProxy,
                           geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotRect = geo[plotFrame]
        let relativeY = location.y - plotRect.minY
        guard let name: String = proxy.value(atY: relativeY) else { return }
        navigation.drillIntoHistory(filter: .secondaryName(name))
    }
}

private struct TopFeelingsChartAX: AXChartDescriptorRepresentable {
    let dataset: InsightsDataset

    func makeChartDescriptor() -> AXChartDescriptor {
        InsightsChartDescriptor.barCategorical(
            title: "Top feelings",
            items: dataset.topFeelings.map { (category: $0.name, count: $0.count) }
        )
    }
}

private struct InsightsByDayOfWeekCard: View {
    @Environment(AppNavigation.self) private var navigation
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("By day of week").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                    Spacer()
                    Text("Tap a bar to filter History")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
                Text("When you tend to check in")
                    .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Chart(dataset.byDayOfWeek, id: \.weekday) { entry in
                    BarMark(
                        x: .value("Day", entry.label),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(Color.OF.accent)
                    .accessibilityLabel(entry.label)
                    .accessibilityValue(checkInCountPhrase(entry.count))
                }
                .accessibilityLabel(InsightsSummary.byDayOfWeek(dataset.byDayOfWeek))
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.OF.divider)
                        AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleTap(at: location, proxy: proxy, geo: geo)
                            }
                    }
                }
            }
        }
    }

    private func handleTap(at location: CGPoint,
                           proxy: ChartProxy,
                           geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotRect = geo[plotFrame]
        let relativeX = location.x - plotRect.minX
        guard let label: String = proxy.value(atX: relativeX) else { return }
        let symbols = Calendar.current.shortWeekdaySymbols
        guard let index = symbols.firstIndex(of: label) else { return }
        navigation.drillIntoHistory(filter: .weekday(index + 1))
    }
}

private struct InsightsIntensityTrendCard: View {
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Intensity").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                Text("Average per day")
                    .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Chart {
                    ForEach(dataset.intensityTrend, id: \.day) { entry in
                        if let avg = entry.avgIntensity {
                            LineMark(
                                x: .value("Day", entry.day, unit: .day),
                                y: .value("Intensity", avg)
                            )
                            .foregroundStyle(Color.OF.accent)
                            .interpolationMethod(.monotone)
                            .accessibilityHidden(true)
                            PointMark(
                                x: .value("Day", entry.day, unit: .day),
                                y: .value("Intensity", avg)
                            )
                            .foregroundStyle(Color.OF.accent)
                            .symbolSize(40)
                            .accessibilityLabel(entry.day.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue(String(format: "intensity %.1f of 5", avg))
                        }
                    }
                }
                .accessibilityLabel(InsightsSummary.intensityTrend(dataset.intensityTrend))
                .chartYScale(domain: 1...5)
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 2, 3, 4, 5]) { _ in
                        AxisGridLine().foregroundStyle(Color.OF.divider)
                        AxisValueLabel().font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, dataset.intensityTrend.count / 6))) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.OF.caption)
                            .foregroundStyle(Color.OF.textMuted)
                    }
                }
            }
        }
    }
}

private struct InsightsBodyChart: View {
    @Environment(AppNavigation.self) private var navigation
    let dataset: InsightsDataset

    var body: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Body").font(.OF.bodyEmphasis).foregroundStyle(Color.OF.text)
                    Spacer()
                    Text("Tap a bar to filter History")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
                Text("Where the feelings live")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Chart(dataset.topBodyRegions, id: \.region) { entry in
                    BarMark(
                        x: .value("Count", entry.count),
                        y: .value("Region", entry.region.displayName)
                    )
                    .foregroundStyle(Color.OF.accent)
                    .accessibilityLabel(entry.region.displayName)
                    .accessibilityValue(checkInCountPhrase(entry.count))
                }
                .accessibilityLabel(InsightsSummary.body(dataset.topBodyRegions))
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
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleTap(at: location, proxy: proxy, geo: geo)
                            }
                    }
                }
            }
        }
    }

    private func handleTap(at location: CGPoint,
                           proxy: ChartProxy,
                           geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotRect = geo[plotFrame]
        let relativeY = location.y - plotRect.minY
        guard let regionName: String = proxy.value(atY: relativeY) else { return }
        guard let region = BodyRegion.allCases.first(where: { $0.displayName == regionName }) else { return }
        navigation.drillIntoHistory(filter: .bodyRegion(region))
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
                        .foregroundStyle(Color.OF.core(point.coreID))
                        .symbolSize(60)
                        .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .shortened))
                        .accessibilityValue(String(format: "energy %.1f, valence %.1f",
                                                   point.energy, point.valence))
                    }
                }
                .accessibilityLabel(InsightsSummary.moodScatter(dataset.moodPoints.count))
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
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        if let plotAnchor = proxy.plotFrame {
                            let plot = geo[plotAnchor]
                            ZStack {
                                quadLabel("calm · pleasant",     alignment: .topLeading)
                                quadLabel("active · pleasant",   alignment: .topTrailing)
                                quadLabel("calm · unpleasant",   alignment: .bottomLeading)
                                quadLabel("active · unpleasant", alignment: .bottomTrailing)
                            }
                            .frame(width: plot.width, height: plot.height)
                            .position(x: plot.midX, y: plot.midY)
                        }
                    }
                }
            }
        }
    }

    private func quadLabel(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(.OF.caption.italic())
            .foregroundStyle(Color.OF.textMuted)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

/// VoiceOver-friendly pluralization for chart count values.
/// "1 check-in" / "5 check-ins" / "no check-ins".
func checkInCountPhrase(_ count: Int) -> String {
    switch count {
    case 0: "no check-ins"
    case 1: "1 check-in"
    default: "\(count) check-ins"
    }
}

enum InsightsSummary {
    static func checkInsPerDay(totalCount: Int, dayCount: Int) -> String {
        "Check-ins per day chart, \(checkInCountPhrase(totalCount)) over \(dayCount) day\(dayCount == 1 ? "" : "s")"
    }

    static func byCore(_ entries: [InsightsDataset.CoreCount]) -> String {
        guard let top = entries.first else {
            return "By core chart, no data"
        }
        return "By core chart, top is \(top.coreName) with \(checkInCountPhrase(top.count))"
    }

    static func topFeelings(_ entries: [InsightsDataset.FeelingCount]) -> String {
        guard let top = entries.first else {
            return "Top feelings chart, no data"
        }
        return "Top feelings chart, top is \(top.name) with \(checkInCountPhrase(top.count))"
    }

    static func byDayOfWeek(_ entries: [InsightsDataset.DOWCount]) -> String {
        let busiest = entries.max(by: { $0.count < $1.count })
        guard let top = busiest, top.count > 0 else {
            return "By day of week chart, no data"
        }
        return "By day of week chart, busiest is \(top.label) with \(checkInCountPhrase(top.count))"
    }

    static func intensityTrend(_ entries: [InsightsDataset.DayIntensity]) -> String {
        let values = entries.compactMap(\.avgIntensity)
        guard !values.isEmpty else { return "Intensity trend chart, no data" }
        let avg = values.reduce(0, +) / Double(values.count)
        return String(format: "Intensity trend chart, average %.1f of 5 across %d day%@",
                      avg, values.count, values.count == 1 ? "" : "s")
    }

    static func body(_ entries: [InsightsDataset.BodyRegionCount]) -> String {
        guard let top = entries.first else {
            return "Body chart, no regions captured"
        }
        return "Body chart, most-felt is \(top.region.displayName) with \(checkInCountPhrase(top.count))"
    }

    static func moodScatter(_ pointCount: Int) -> String {
        "Mood scale chart, \(pointCount) data point\(pointCount == 1 ? "" : "s")"
    }
}

enum InsightsChartDescriptor {
    static func barCategorical(title: String,
                               items: [(category: String, count: Int)]) -> AXChartDescriptor {
        let categories = items.map(\.category)
        let categoryOrder = categories.isEmpty ? ["No data"] : categories
        let maxCount = max(1, items.map(\.count).max() ?? 1)
        let xAxis = AXCategoricalDataAxisDescriptor(title: title, categoryOrder: categoryOrder)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Check-ins",
            range: 0.0...Double(maxCount),
            gridlinePositions: [0.0, Double(maxCount)]
        ) { value in
            checkInCountPhrase(Int(value.rounded()))
        }
        let sourceItems = items.isEmpty ? [(category: "No data", count: 0)] : items
        let points = sourceItems.map { item in
            AXDataPoint(x: item.category,
                        y: Double(item.count),
                        additionalValues: [],
                        label: item.category)
        }
        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: false,
            dataPoints: points
        )

        return AXChartDescriptor(
            title: title,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview { NavigationStack { InsightsView() } }
