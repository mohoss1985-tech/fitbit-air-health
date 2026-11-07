import SwiftUI

/// Today: one calm read, then the detail right below it (DESIGN_SPEC §4).
/// Order: header (menu · greeting · +) → day circles → verdict over orbs → rings → freshness →
/// strain target → stress → panels → drift → health monitor → last night → your week →
/// weekly report (Mondays) → journal → footer.
struct TodayView: View {
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Ticks light up one by one only on the first open of the day (decided once per view life).
    @State private var animateRings = TickRingGate.firstOpenToday("today.rings")
    @State private var selectedDay: Date?

    private var now: Date { Demo.now }
    private var hour: Int { Calendar.current.component(.hour, from: now) }
    private var isEvening: Bool { hour >= 18 || hour < 4 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(proxy)
                    VStack(alignment: .leading, spacing: Space.cardGap) {
                        StrainTargetCard()
                        StressCard()
                        PanelsStrip { nav.tab = .body }
                        DriftBanner()
                        HealthMonitorCard()
                        if let s = health.lastSleep { LastNightCard(session: s) }

                        SectionLabel("Your week")
                            .padding(.top, Space.section - Space.cardGap)
                            .id("week")
                        SleepBalanceCard()
                        WeekStrip(selected: $selectedDay)

                        if Calendar.current.component(.weekday, from: now) == 2 {
                            WeeklyReportCard()   // Mondays: last week's report (owned by Trends + Week)
                                .padding(.top, Space.section - Space.cardGap)
                        }

                        JournalCard { nav.showJournal = true }
                            .padding(.top, Space.section - Space.cardGap)

                        footer
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.xxl)
                }
            }
            .scrollIndicators(.hidden)
            .background(Theme.paper)
            .refreshable { await health.refresh() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header (the only place with orbs)

    private func header(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            topBar
            DayCircles(days: Array(health.history.suffix(7))) { day in
                selectedDay = day
                Motion.animate(Motion.morph) { proxy.scrollTo("week", anchor: .top) }
            }
            Text(verdict)
                .typo(.title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            rings
            statusLines
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.section)
        .background(alignment: .top) {
            OrbBackground(tier: recoveryTier, evening: isEvening)
                .frame(height: 480)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.6),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                // Bleed up behind the status bar so the header has no grey strip.
                .padding(.top, -60)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: Space.m) {
            RoundIconButton(systemName: "line.3.horizontal", label: "Menu") { nav.showMenu = true }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(health.greeting(at: now)).typo(.headline).foregroundStyle(Theme.ink)
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .typo(.caption).foregroundStyle(Theme.ink2)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            RoundIconButton(systemName: "plus", label: "Tag today in your journal") { nav.showJournal = true }
        }
    }

    // MARK: Verdict (time-of-day aware, ≤14 words)

    private var verdict: String {
        if hour >= 4 && hour < 12 { return morningVerdict }
        if hour >= 12 && hour < 18 { return afternoonVerdict }
        return eveningVerdict
    }

    private var morningVerdict: String {
        guard let r = health.recovery else { return "Calibrating. A few more nights with the Air." }
        let t = Scores.strainTarget(r)
        if r.score >= 67 { return "Recovered. Room for a hard session, strain \(Int(t.lowerBound))–\(Int(t.upperBound))." }
        if r.score >= 34 { return "Partly recovered. Keep today moderate." }
        return "Run down. Make today an easy one."
    }

    private var afternoonVerdict: String {
        let t = Scores.strainTarget(health.recovery)
        let s = health.strain?.value ?? 0
        let range = "\(Int(t.lowerBound))–\(Int(t.upperBound))"
        if s >= t.upperBound { return "Past your strain target. Ease off to protect tomorrow." }
        if s >= t.lowerBound { return "In your strain target of \(range). Anything more is optional." }
        return String(format: "Strain %.1f of your %@ target. Room for a session.", locale: .current, s, range)
    }

    private var eveningVerdict: String {
        guard let bed = bedtimeTarget else { return "Wind down soon. A regular bedtime helps tomorrow’s recovery." }
        return "Wind down soon. Bed by \(bed.formatted(date: .omitted, time: .shortened)) for a full night."
    }

    /// Bedtime from your usual wake time over the last 3 nights, plus 8 h need,
    /// a little extra when in debt, and 15 min to fall asleep.
    private var bedtimeTarget: Date? {
        let last = health.recentNights.suffix(3)
        guard !last.isEmpty else { return nil }
        let cal = Calendar.current
        let wakeMins = last.map { n -> Double in
            let c = cal.dateComponents([.hour, .minute], from: n.end)
            return Double((c.hour ?? 7) * 60 + (c.minute ?? 0))
        }
        let wake = wakeMins.reduce(0, +) / Double(wakeMins.count)
        let extra = min(Insights.sleepDebt(health.recentNights) / 7, 30)
        var bed = wake - Scores.sleepNeedMinutes - extra - 15
        if bed < 0 { bed += 1440 }
        let rounded = (Int(bed) / 5) * 5
        let base = cal.startOfDay(for: now)
        let d = cal.date(byAdding: .minute, value: rounded, to: base) ?? now
        return d < now.addingTimeInterval(-3600 * 6) ? cal.date(byAdding: .day, value: 1, to: d) : d
    }

    // MARK: Rings (Sleep · Recovery · Strain, recovery is the hero)

    private var recoveryTier: StatusTier? {
        guard let s = health.recovery?.score else { return nil }
        return s >= 67 ? .inRange : (s >= 34 ? .watch : .outOfRange)
    }


    @ViewBuilder private var rings: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: Space.xl) {
                heroRing.frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: Space.xl) { sleepRing; strainRing }
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .center, spacing: 0) {
                sleepRing.frame(maxWidth: .infinity)
                heroRing
                strainRing.frame(maxWidth: .infinity)
            }
        }
    }

    private var heroRing: some View {
        let score = health.recovery?.score
        return NavigationLink(value: Route.score(.recovery)) {
            VStack(spacing: Space.s) {
                TickRing(progress: Double(score ?? 0) / 100,
                         color: recoveryTier?.fill ?? Theme.hair,
                         size: 172,
                         animateOnAppear: animateRings,
                         accessibilityName: "Recovery") {
                    ValueText(value: score.map(String.init) ?? "—", unit: score == nil ? "" : "%", size: .display)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, Space.xl)
                }
                Text("Recovery").typo(.label).foregroundStyle(Theme.ink2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recovery")
        .accessibilityValue(score.map { "\($0) percent, \(recoveryTier?.word ?? "")" } ?? "Calibrating")
        .accessibilityHint("Shows what drove it")
    }

    private var sleepRing: some View {
        smallRing(.sleep, title: "Sleep",
                  value: health.sleepScore.map(String.init),
                  progress: Double(health.sleepScore ?? 0) / 100,
                  color: Theme.iris,
                  spoken: health.sleepScore.map { "\($0) out of 100" })
    }

    private var strainRing: some View {
        smallRing(.strain, title: "Strain",
                  value: health.strain.map { String(format: "%.1f", locale: .current, $0.value) },
                  progress: (health.strain?.value ?? 0) / 21,
                  color: Theme.ember,
                  spoken: health.strain.map { String(format: "%.1f out of 21", locale: .current, $0.value) })
    }

    private func smallRing(_ kind: ScoreKind, title: String, value: String?, progress: Double,
                           color: Color, spoken: String?) -> some View {
        NavigationLink(value: Route.score(kind)) {
            VStack(spacing: Space.s) {
                TickRing(progress: progress, color: color, size: 76, ticks: 36,
                         animateOnAppear: animateRings, accessibilityName: title) {
                    Text(value ?? "—")
                        .typo(.headline)
                        .foregroundStyle(value == nil ? Theme.graphite : Theme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                Text(title).typo(.label).foregroundStyle(Theme.ink2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken ?? "No reading")
        .accessibilityHint("Shows details")
    }

    // MARK: Status lines under the rings

    private var statusLines: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SyncNowButton(date: health.latestSampleDate)
            HStack(spacing: Space.s) {
                if let t = recoveryTier { StatusChip(tier: t) }
                FreshnessChip(date: health.latestSampleDate)
                if Demo.isOn {
                    Text(Demo.chipText)
                        .typo(.label)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, Space.s)
                        .padding(.vertical, Space.xs)
                        .overlay(RoundedRectangle(cornerRadius: Radius.chip).strokeBorder(Theme.ink.opacity(0.3), lineWidth: 0.5))
                        .accessibilityLabel("Showing sample data, not your readings")
                }
                Spacer(minLength: 0)
            }
            if let signals = health.recovery?.signalsText {
                let notSent = health.recovery?.missingInputs.contains(where: \.isNotSentByGoogle) ?? false
                Text(signals + (notSent ? ". HRV is not sent by Google Health." : "."))
                    .typo(.caption).foregroundStyle(Theme.ink2)
            }
            if health.lastSleep != nil && !health.isSleepFresh {
                Label {
                    Text("Last night hasn’t reached Apple Health yet. Scores use the night ending \(health.sleepDayText). Open Google Health, then pull down.")
                } icon: {
                    Image(systemName: "clock")
                }
                .typo(.caption)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Space.xs) {
            if let date = health.lastRefresh {
                Text("Updated \(date.formatted(date: .omitted, time: .shortened)). Pull down to refresh.")
            }
            Text("Wellness estimates, not medical advice.")
        }
        .typo(.caption)
        .foregroundStyle(Theme.graphite)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.top, Space.section - Space.cardGap)
    }
}

// MARK: - Day circles (top of Today): each day ringed by its recovery

private struct DayCircles: View {
    let days: [DaySummary]
    let onTap: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { d in
                let isToday = Calendar.current.isDate(d.date, inSameDayAs: Demo.now)
                Button { onTap(d.date) } label: {
                    VStack(spacing: Space.xs) {
                        Text(d.date.formatted(.dateTime.weekday(.narrow)))
                            .typo(.micro).foregroundStyle(Theme.ink2)
                        ZStack {
                            if isToday { Circle().fill(Theme.ink).padding(5) }
                            Circle().stroke(Theme.hair, lineWidth: 2.5)
                            Circle()
                                .trim(from: 0, to: Double(d.recovery ?? 0) / 100)
                                .stroke(tier(d.recovery)?.fill ?? Theme.hair,
                                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text(d.date.formatted(.dateTime.day()))
                                .typo(.label)
                                .foregroundStyle(isToday ? Theme.paper : Theme.ink)
                        }
                        .frame(width: 38, height: 38)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isToday ? "Today" : d.date.formatted(.dateTime.weekday(.wide).day()))
                .accessibilityValue(d.recovery.map { "Recovery \($0) percent, \(tier($0)?.word ?? "")" } ?? "No reading")
                .accessibilityHint("Shows this day in Your week")
            }
        }
    }

    private func tier(_ r: Int?) -> StatusTier? {
        guard let r else { return nil }
        return r >= 67 ? .inRange : (r >= 34 ? .watch : .outOfRange)
    }
}
