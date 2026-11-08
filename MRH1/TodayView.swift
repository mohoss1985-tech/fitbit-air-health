import SwiftUI

/// Today: one calm read, then the detail right below it (DESIGN_SPEC_v1.3 §4, supersedes DESIGN_SPEC §4).
/// Order: header (menu · greeting + date · +) → verdict over orbs → rings (Sleep · Recovery · Strain) →
/// freshness / status lines → body panels → "Today | Week" switch (pinned once scrolled) →
///   Today: coach note (if any) → strain target → last night → stress → drift banner (when drifting) →
///          health monitor (folds to one row when quiet) → journal → footer.
///   Week:  day circles (select a day in place) → weekly report (Mondays) → sleep balance → week strip → footer.
/// When the big rings scroll away a compact gauge bar (36 pt rings) pins above the switch (TodayPinned.swift).
/// Nothing pins at accessibility type sizes. Do not put the M–S day circles back in the header.
struct TodayView: View {
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav
    @Environment(JournalStore.self) private var journal
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(CoachPrefs.Key.enabled) private var coachOn = CoachPrefs.defaultEnabled
    @AppStorage(CoachPrefs.Key.proactive) private var proactive = CoachPrefs.defaultProactive.rawValue

    /// Ticks light up one by one only on the first open of the day (decided once per view life).
    @State private var animateRings = TickRingGate.firstOpenToday("today.rings")
    @State private var selectedDay: Date?

    /// Segment + the day it was picked: a pick from an earlier day falls back to the default
    /// (Week on Mondays while the weekly report is new, Today otherwise).
    @SceneStorage("today.segment") private var segmentRaw = ""
    @SceneStorage("today.segmentDay") private var segmentDay = ""

    // Scroll tracking (global y, relative to the top of the safe area).
    @State private var safeTop: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var gaugeProgress: Double = 0
    @State private var switchPinned = false
    @State private var atTop = true

    private var now: Date { Demo.now }
    private var hour: Int { Calendar.current.component(.hour, from: now) }
    private var isEvening: Bool { hour >= 18 || hour < 4 }
    private var pins: Bool { typeSize < .accessibility1 }

    private var dayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: now)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    private var defaultSegment: TodaySegment {
        Calendar.current.component(.weekday, from: now) == 2 ? .week : .today
    }
    private var segment: Binding<TodaySegment> {
        Binding(get: {
            segmentDay == dayKey ? (TodaySegment(rawValue: segmentRaw) ?? defaultSegment) : defaultSegment
        }, set: {
            segmentRaw = $0.rawValue
            segmentDay = dayKey
        })
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    PanelsStrip { nav.tab = .body }
                        .padding(.horizontal, Space.gutter)
                        .id("today.panels")
                        .overlay(alignment: .bottom) {
                            // Scroll target whose top is one gauge bar above the switch: scrolling it to the top
                            // lands the switch exactly on its pinned line.
                            Color.clear
                                .frame(height: max(0, (pins ? TodayPinned.compactHeight : 0) - (Space.xl - Space.xs)))
                                .id("today.switch")
                                .accessibilityHidden(true)
                        }
                    // Panels → switch Space.xl (the bar carries Space.xs of it), switch → first card Space.m.
                    TodaySwitchBar(segment: segment)
                        .padding(.top, Space.xl - Space.xs)
                        .opacity(switchPinned ? 0 : 1)
                        .accessibilityHidden(switchPinned)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY + (Space.xl - Space.xs) } action: { y in
                            track(switchTop: y)
                        }
                    ZStack(alignment: .top) {
                        // A short segment (Week) still fills the screen under the pinned stack, so switching
                        // segments while pinned never makes the page jump. A spacer, not a min-height frame:
                        // the cards keep their ideal heights (WeekStrip's horizontal ScrollView would stretch).
                        Color.clear
                            .frame(height: pins ? max(0, viewportHeight - TodayPinned.compactHeight - TodayPinned.switchHeight
                                                       - (Space.m - Space.s) - Space.xxl) : 0)
                            .accessibilityHidden(true)
                        if segment.wrappedValue == .today {
                            todaySegment.fixedSize(horizontal: false, vertical: true).transition(.opacity)
                        } else {
                            weekSegment.fixedSize(horizontal: false, vertical: true).transition(.opacity)
                        }
                    }
                    .padding(.top, Space.m - Space.s)
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.xxl)
                }
            }
            .scrollIndicators(.hidden)
            .scrollsToTopOnReselect(.today)
            .modifier(TopOffsetTracker(atTop: $atTop))
            .background(Theme.paper)
            .overlay(alignment: .top) {
                if pins && (gaugeProgress > 0 || switchPinned) {
                    TodayPinnedStack(progress: gaugeProgress, switchPinned: switchPinned, segment: segment)
                }
            }
            .background {
                GeometryReader { g in
                    Color.clear
                        .onAppear {
                            safeTop = g.frame(in: .global).minY + g.safeAreaInsets.top
                            viewportHeight = g.size.height
                        }
                        .onChange(of: g.frame(in: .global).minY + g.safeAreaInsets.top) { _, v in safeTop = v }
                        .onChange(of: g.size.height) { _, v in viewportHeight = v }
                }
            }
            .refreshable { await health.refresh() }
            // Switching while pinned keeps the switch where it is and shows the new segment from its top.
            .onChange(of: segment.wrappedValue) { _, _ in
                guard switchPinned else { return }
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { proxy.scrollTo("today.switch", anchor: .top) }
            }
            // A second reselect of the Today tab while already at the top goes "home" (Today segment).
            .onChange(of: nav.scrollTopTick[.today]) { _, _ in
                if atTop && segment.wrappedValue != .today {
                    Motion.animate(Motion.crossfade) { segment.wrappedValue = .today }
                }
            }
            .task { await applyLaunchArguments(proxy) }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Segments

    private var todaySegment: some View {
        VStack(alignment: .leading, spacing: Space.cardGap) {
            if let note = coachNote { CoachNoteCard(note: note) }
            StrainTargetCard()
            if let s = health.lastSleep { LastNightCard(session: s) }
            StressCard()
            DriftBanner()
            HealthMonitorCard().id("today.monitor")

            JournalCard { nav.showJournal = true }
                .padding(.top, Space.section - Space.cardGap)

            footer
        }
    }

    private var weekSegment: some View {
        VStack(alignment: .leading, spacing: Space.cardGap) {
            // Selects a day card in place: WeekStrip centres it horizontally, the page does not scroll.
            DayCircles(days: Array(health.history.suffix(7)), selected: selectedDay) { day in
                Motion.animate(Motion.morph) { selectedDay = day }
            }
            if Calendar.current.component(.weekday, from: now) == 2 {
                WeeklyReportCard()   // Mondays: last week's report (owned by Trends + Week)
            }
            SleepBalanceCard()
            WeekStrip(selected: $selectedDay)
            footer
        }
    }

    // MARK: Scroll tracking → compact gauge bar + pinned switch

    private func track(ringsBottom yGlobal: CGFloat) {
        let y = yGlobal - safeTop
        let h = TodayPinned.compactHeight
        var p: Double
        if #available(iOS 18, *) {
            // Morph tied to scroll: starts as the rings' labels reach the bar, done once they're under it.
            p = Double((h + 40 - y) / 40)
            p = (max(0, min(p, 1)) * 50).rounded() / 50
        } else {
            p = y < h + 8 ? 1 : 0
        }
        guard p != gaugeProgress else { return }
        if #available(iOS 18, *) { gaugeProgress = p } else { Motion.animate(Motion.enter) { gaugeProgress = p } }
    }

    private func track(switchTop yGlobal: CGFloat) {
        let pinned = pins && (yGlobal - safeTop) <= TodayPinned.compactHeight
        if pinned != switchPinned { switchPinned = pinned }
    }

    /// Screenshot hooks (same family as `-tab` / `-open`): `-segment today|week`,
    /// `-todayScroll gauges|pinned|monitor` (gauge bar only / gauge bar + pinned switch / health monitor).
    private func applyLaunchArguments(_ proxy: ScrollViewProxy) async {
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let s = value("-segment").flatMap(TodaySegment.init(rawValue:)) { segment.wrappedValue = s }
        guard let scroll = value("-todayScroll") else { return }
        try? await Task.sleep(for: .seconds(2.5))
        switch scroll {
        case "gauges": proxy.scrollTo("today.panels", anchor: .top)
        case "pinned": proxy.scrollTo("today.switch", anchor: .top)
        case "monitor": proxy.scrollTo("today.monitor", anchor: .center)
        default: break
        }
    }

    // MARK: Coach note (v1.1, rule-based, under the freshness chips)

    /// One proactive note from `CoachRules` (no model), only with the coach on and notes allowed.
    /// "Important only" waits until a signal is outside its usual range or Recovery is red.
    private var coachNote: CoachNote? {
        guard coachOn else { return nil }
        let mode = CoachPrefs.Proactive(rawValue: proactive) ?? CoachPrefs.defaultProactive
        guard mode != .off else { return nil }
        if mode == .important {
            let drifting = HealthMonitorCard.vitals.contains { health.state($0).isConcern }
            let red = (health.recovery?.score ?? 100) < 34
            guard drifting || red else { return nil }
        }
        return CoachRules.evaluate(health, journal: journal).note
    }

    // MARK: Header (the only place with orbs)

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            topBar
            Text(verdict)
                .typo(.title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            rings
                // One gentle CoachMark for the three scores, in the free top-right corner.
                .overlay(alignment: .topTrailing) {
                    CoachMarkSlot(metric: nil, name: "today’s scores")
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { y in
                    track(ringsBottom: y)
                }
            statusLines
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.xl)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { y in
            // iOS 17 has no onScrollGeometryChange: the header's own position says "at the top".
            if #unavailable(iOS 18) { atTop = y - safeTop >= -2 }
        }
        .background(alignment: .top) {
            OrbBackground(tier: recoveryTier, evening: isEvening)
                .frame(height: 480)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.55),
                                             .init(color: .clear, location: 0.92)],
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
        let t = Scores.todayStrainTarget(health)
        // The coach's cap (e.g. two hard days in a row) wins, so the headline matches the Coach note below it.
        let cap = CoachRules.todayCap(health)
        if (cap == .rest || cap == .easy) && r.score >= 34 {
            return r.score >= 67 ? "Recovered, but keep today easy." : "Partly recovered. Keep today easy."
        }
        if cap == .moderate && r.score >= 67 { return "Recovered. Keep today steady." }
        if r.score >= 67 { return "Recovered. Room for a hard session, strain \(Int(t.lowerBound))–\(Int(t.upperBound))." }
        if r.score >= 34 { return "Partly recovered. Keep today moderate." }
        return "Run down. Make today an easy one."
    }

    private var afternoonVerdict: String {
        let t = Scores.todayStrainTarget(health)
        let s = health.strain?.value ?? 0
        let range = "\(Int(t.lowerBound))–\(Int(t.upperBound))"
        if s >= t.upperBound { return "Past your strain target. Ease off to protect tomorrow." }
        if s >= t.lowerBound { return "In your strain target of \(range). Anything more is optional." }
        let cap = CoachRules.todayCap(health)
        if cap == .rest || cap == .easy {
            return String(format: "Strain %.1f of your %@ target. Easy day: a walk is enough.", locale: .current, s, range)
        }
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

    private var recoveryTier: StatusTier? { todayRecoveryTier(health.recovery?.score) }


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
            SyncNowButton(date: health.latestSampleDate, checked: health.lastRefresh)
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

// MARK: - Day circles (Week segment): each day ringed by its recovery, selects a day card in place

private struct DayCircles: View {
    let days: [DaySummary]
    let selected: Date?
    let onTap: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { d in
                let isToday = Calendar.current.isDate(d.date, inSameDayAs: Demo.now)
                let isSelected = selected.map { Calendar.current.isDate($0, inSameDayAs: d.date) } ?? false
                Button { onTap(d.date) } label: {
                    VStack(spacing: Space.xs) {
                        Text(d.date.formatted(.dateTime.weekday(.narrow)))
                            .typo(.micro).foregroundStyle(Theme.ink2)
                        ZStack {
                            if isToday { Circle().fill(Theme.ink).padding(5) }
                            Circle().stroke(Theme.hair, lineWidth: 2.5)
                            Circle()
                                .trim(from: 0, to: Double(d.recovery ?? 0) / 100)
                                .stroke(todayRecoveryTier(d.recovery)?.fill ?? Theme.hair,
                                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text(d.date.formatted(.dateTime.day()))
                                .typo(.label)
                                .foregroundStyle(isToday ? Theme.paper : Theme.ink)
                        }
                        .frame(width: 38, height: 38)
                        // Selected day: a small ink dot under the circle (no layout change).
                        Circle().fill(Theme.ink).frame(width: 4, height: 4).opacity(isSelected ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isToday ? "Today" : d.date.formatted(.dateTime.weekday(.wide).day()))
                .accessibilityValue(d.recovery.map { "Recovery \($0) percent, \(todayRecoveryTier($0)?.word ?? "")" } ?? "No reading")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint("Shows this day’s card below")
            }
        }
    }
}

// MARK: - Top-of-scroll tracking (second tab reselect at the top → Today segment)

private struct TopOffsetTracker: ViewModifier {
    @Binding var atTop: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollGeometryChange(for: Bool.self) { g in
                g.contentOffset.y + g.contentInsets.top <= 2
            } action: { _, top in
                atTop = top
            }
        } else {
            content   // iOS 17: the header's position sets atTop (see `header`).
        }
    }
}
