// OpenFeelings/Views/TodayView.swift
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var allLogs: [FeelingLog]
    @Query(sort: \Intention.date, order: .reverse) private var allIntentions: [Intention]
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
                .ofDisplay()
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.lg)
    }

    private var dateString: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    // MARK: - Intention placeholder card

    @ViewBuilder
    private var intentionPlaceholder: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Today's intention".uppercased())
                    .font(.OF.caption)
                    .tracking(1.0)
                    .foregroundStyle(Color.OF.textMuted)
                if let intention = todaysIntention,
                   !intention.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(intention.text)
                        .font(.OF.body)
                        .foregroundStyle(Color.OF.text)
                    Button("Edit") { navigation.select(.direction) }
                        .font(.OF.caption.weight(.medium))
                        .foregroundStyle(Color.OF.accent)
                } else {
                    Button {
                        navigation.select(.direction)
                    } label: {
                        Text("Set today's intention")
                            .font(.OF.body)
                            .foregroundStyle(Color.OF.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var todaysIntention: Intention? {
        let today = Calendar.current.startOfDay(for: Date())
        return allIntentions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    // MARK: - Today's logs

    private var todaysSection: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "\(todaysLogs.count) check-in\(todaysLogs.count == 1 ? "" : "s") today")
            ForEach(todaysLogs) { log in
                OFCard { logCardContent(log) }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Self.todayLogAXLabel(for: log))
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
                if log.captureSource == "watch" {
                    Label("Apple Watch", systemImage: "applewatch")
                        .labelStyle(.iconOnly)
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                        .accessibilityLabel("From Apple Watch")
                }
            }
            if let summary = bodySummary(for: log) {
                Text(summary)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            if let context = contextSummary(for: log) {
                Text(context)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            if let triggersCoping = triggersCopingSummary(for: log) {
                Text(triggersCoping)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            if let mood = moodScaleSummary(for: log) {
                Text(mood)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            if !log.note.isEmpty {
                Text("\u{201C}\(log.note)\u{201D}")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .lineLimit(2)
            }
        }
    }

    private func bodySummary(for log: FeelingLog) -> String? {
        let regions = log.bodyRegions.map(\.displayName.localizedLowercase)
        let sensations = log.bodySensations.map(\.displayName.localizedLowercase)
        guard !regions.isEmpty || !sensations.isEmpty else { return nil }
        let regionPart   = regions.isEmpty   ? "" : regions.joined(separator: ", ")
        let sensationPart = sensations.isEmpty ? "" : sensations.joined(separator: ", ")
        if !regionPart.isEmpty && !sensationPart.isEmpty {
            return "\(regionPart) · \(sensationPart)"
        }
        return regionPart.isEmpty ? "· \(sensationPart)" : regionPart
    }

    private func contextSummary(for log: FeelingLog) -> String? {
        let places = log.contextPlaces.map(\.displayName.localizedLowercase)
        let people = log.contextPeople.map(\.displayName.localizedLowercase)
        guard !places.isEmpty || !people.isEmpty else { return nil }
        let placePart  = places.isEmpty ? "" : places.joined(separator: ", ")
        let peoplePart = people.isEmpty ? "" : people.joined(separator: ", ")
        if !placePart.isEmpty && !peoplePart.isEmpty {
            return "\(placePart) · \(peoplePart)"
        }
        return placePart.isEmpty ? peoplePart : placePart
    }

    private func triggersCopingSummary(for log: FeelingLog) -> String? {
        let triggers = log.triggers.map(\.displayName.localizedLowercase)
        let coping   = log.coping.map(\.displayName.localizedLowercase)
        guard !triggers.isEmpty || !coping.isEmpty else { return nil }
        let triggerPart = triggers.isEmpty ? "" : triggers.joined(separator: ", ")
        let copingPart  = coping.isEmpty   ? "" : coping.joined(separator: ", ")
        if !triggerPart.isEmpty && !copingPart.isEmpty {
            return "\(triggerPart) → \(copingPart)"
        }
        return triggerPart.isEmpty ? copingPart : triggerPart
    }

    private func moodScaleSummary(for log: FeelingLog) -> String? {
        let energy  = log.moodEnergy.map(MoodScale.energyBand)
        let valence = log.moodValence.map(MoodScale.valenceBand)
        guard energy != nil || valence != nil else { return nil }
        let parts = [energy, valence].compactMap { $0 }
        return parts.joined(separator: " · ")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.weekSummaryAXLabel(for: summary))
        }
    }

    nonisolated static func todayLogAXLabel(for log: FeelingLog) -> String {
        let time = log.createdAt.formatted(.dateTime.hour().minute())
        let path = log.pathTitle.replacingOccurrences(of: " > ", with: ", ")
        var parts = ["\(time): \(path)"]
        if let intensity = log.intensity {
            parts.append("intensity \(intensity) of 5")
        }
        if log.captureSource == "watch" {
            parts.append("from Apple Watch")
        }
        return parts.joined(separator: ", ")
    }

    nonisolated static func weekSummaryAXLabel(for summary: WeekSummary?) -> String {
        guard let summary else { return "Week summary" }
        return "This week: \(summary.totalCount) check-ins, top feeling \(summary.topCoreName)"
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

}

#Preview {
    NavigationStack { TodayView() }
        .environment(AppNavigation())
}
