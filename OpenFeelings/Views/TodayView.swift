// OpenFeelings/Views/TodayView.swift
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var allLogs: [FeelingLog]
    @AppStorage("displayName") private var displayName = ""

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private var todaysLogs: [FeelingLog] {
        allLogs.filter { $0.createdAt >= startOfToday }
    }

    private var weekSummary: WeekSummary? {
        WeekSummary.summarize(logs: allLogs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                header
                if todaysLogs.isEmpty {
                    OFEmptyState(
                        glyph: "leaf.circle",
                        title: "Today is open.",
                        bodyText: "Tap below to name how you're feeling.",
                        primaryAction: .init(label: "Start a check-in") {
                            navigation.select(.checkIn)
                        }
                    )
                    .padding(.top, .OF.xl)
                } else {
                    intentionPlaceholder
                    todaysSection
                    weekSummarySection
                    seeAllLink
                }
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            if let ribbon = navigation.savedRibbon {
                Text("Saved · \(ribbon.timestamp.formatted(.dateTime.hour().minute()))")
                    .font(.OF.bodyEmphasis)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CGFloat.OF.sm)
                    .background(.thinMaterial)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .OF.gentle, value: navigation.savedRibbon)
        .navigationDestination(for: HistoryRoute.self) { _ in
            HistoryView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text(dateString)
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text(Greeting.text(for: Date(), name: displayName))
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.lg)
    }

    private var dateString: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    // MARK: - Intention placeholder card

    private var intentionPlaceholder: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Today's intention".uppercased())
                    .font(.OF.caption)
                    .tracking(1.0)
                    .foregroundStyle(Color.OF.textMuted)
                Text("Coming soon — set what you'd like to feel today.")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
            }
        }
    }

    // MARK: - Today's logs

    private var todaysSection: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "\(todaysLogs.count) check-in\(todaysLogs.count == 1 ? "" : "s") today")
            ForEach(todaysLogs) { log in
                OFCard { logCardContent(log) }
            }
        }
    }

    @ViewBuilder
    private func logCardContent(_ log: FeelingLog) -> some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                .font(.OF.headline)
                .foregroundStyle(Color.OF.text)
            HStack(spacing: .OF.sm) {
                if let intensity = log.intensity {
                    intensityDots(intensity: intensity)
                }
                Text(log.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.OF.mono)
                    .foregroundStyle(Color.OF.textMuted)
                if log.healthSyncStatus == .synced {
                    Label("synced", systemImage: "checkmark.circle.fill")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
            }
            if !log.note.isEmpty {
                Text("\u{201C}\(log.note)\u{201D}")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .lineLimit(2)
            }
        }
    }

    private func intensityDots(intensity: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= intensity ? AnyShapeStyle(Color.OF.accent) : AnyShapeStyle(Color.OF.divider))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Week summary

    @ViewBuilder
    private var weekSummarySection: some View {
        if let summary = weekSummary {
            VStack(alignment: .leading, spacing: .OF.sm) {
                OFSectionHeader(title: "This week")
                Text("Mostly \(summary.topCoreName) · \(summary.totalCount) check-in\(summary.totalCount == 1 ? "" : "s")")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                    .padding(.horizontal, .OF.lg)
            }
        }
    }

    // MARK: - See all history link

    private var seeAllLink: some View {
        NavigationLink(value: HistoryRoute.full) {
            HStack {
                Text("See all history").font(.OF.body).foregroundStyle(Color.OF.accent)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.OF.textMuted)
            }
            .padding(CGFloat.OF.lg)
            .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
        }
    }

    enum HistoryRoute: Hashable { case full }
}

#Preview {
    NavigationStack { TodayView() }
        .environment(AppNavigation())
}
