import SwiftUI

// Cards below the Today header. Each opens with a one-line takeaway (research/01 §11),
// uses fill-only cards on paper, status colours only next to a judgement word.

// MARK: - Card title row (shared by the Today cards)

private struct CardTitle: View {
    let title: String
    var trailing: String? = nil
    var info: (() -> Void)? = nil
    var infoLabel: String = "More about this"
    /// v1.1: CoachMark at the far right of the title row (hidden while the coach is off).
    var coach: CoachTarget? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(title).typo(.headline).foregroundStyle(Theme.ink)
            if let info {
                Button(action: info) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(Theme.graphite)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .padding(.vertical, -Space.m)
                .padding(.horizontal, -Space.m)
                .accessibilityLabel(infoLabel)
            }
            Spacer(minLength: Space.s)
            if let trailing {
                Text(trailing).typo(.label).foregroundStyle(Theme.ink2)
            }
            if let coach {
                CoachMarkSlot(metric: coach.metric, name: coach.name)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }  // glyph centred on the cap height
            }
        }
    }
}

/// What a card's CoachMark asks about: a metric (sheet) or nil (Coach tab), with its spoken name.
struct CoachTarget {
    let metric: MetricID?
    let name: String
}

private func tierDot(_ tier: StatusTier) -> some View {
    Circle().fill(tier.fill).frame(width: 6, height: 6).accessibilityHidden(true)
}

// MARK: - Strain target (capsule gauge + advice)

struct StrainTargetCard: View {
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav

    var body: some View {
        let cap = CoachRules.todayCap(health)
        let target = cap.strainTarget(Scores.strainTarget(health.recovery))
        let now = health.strain?.value ?? 0
        Card {
            CardTitle(title: "Strain target",
                      trailing: String(format: "%.1f of %.0f–%.0f", locale: .current, now, target.lowerBound, target.upperBound),
                      coach: CoachTarget(metric: nil, name: "Strain target"))
            StrainGauge(value: now, target: target)
                .padding(.vertical, Space.xs)
            HStack {
                Text("0"); Spacer(); Text("21")
            }
            .typo(.caption).foregroundStyle(Theme.graphite)
            .accessibilityHidden(true)
            Text(advice(now: now, target: target, cap: cap))
                .typo(.body).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .coachAccessibilityAction { nav.openCoach(about: nil) }
    }

    private func advice(now: Double, target: ClosedRange<Double>, cap: IntensityCap) -> String {
        if now >= target.upperBound { return "Target reached. More digs into tomorrow’s recovery." }
        if now >= target.lowerBound { return "You’re in your target zone for today." }
        if cap == .rest || cap == .easy {
            return String(format: "%.1f so far. Easy day: a walk or mobility is enough.", locale: .current, now)
        }
        return String(format: "%.1f so far. A 30–45 min moderate session gets you there.", locale: .current, now)
    }
}

// MARK: - Stress through the day (24 hourly bars)

struct StressCard: View {
    @Environment(HealthStore.self) private var health
    @State private var showInfo = false

    var body: some View {
        let hours = health.stressHours
        let current = hours.last(where: { $0.level != nil })?.level
        Card {
            CardTitle(title: "Stress today",
                      trailing: current.map { "\(Insights.stressWord($0)) now, \($0.formatted(.number.precision(.fractionLength(0...1)))) of 3" },
                      info: { showInfo = true }, infoLabel: "What is stress?",
                      coach: CoachTarget(metric: nil, name: "Stress today"))
            if hours.isEmpty {
                NotSentLabel(kind: .waiting)
                Text("Hours appear once Google Health syncs today’s heart rate.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            } else {
                Text(headline(hours)).typo(.body).foregroundStyle(Theme.ink)
                bars(hours)
                axis
                legend
                Text("Last synced hour: \(hours.last?.start.formatted(date: .omitted, time: .shortened) ?? "—").")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            }
        }
        .sheet(isPresented: $showInfo) {
            ExplainSheet(title: "Stress (0 – 3)",
                         sub: "Your body’s stress response, hour by hour",
                         what: "When your heart beats faster than your resting level while you are sitting still, that is usually your nervous system reacting to stress, caffeine, a meal or illness. MRH1 measures that gap every hour. Hours when you were walking or exercising are shown as “Moving” and not counted.",
                         rows: [("0 – 1 · Calm", "Close to your resting heart rate."),
                                ("1 – 2 · Medium", "Raised while still: a busy day, coffee, a meal."),
                                ("2 – 3 · High", "Strongly raised while still: stress, illness, alcohol the night before.")])
        }
    }

    private func headline(_ hours: [StressHour]) -> String {
        let levels = hours.compactMap(\.level)
        let high = levels.filter { $0 >= 2 }.count
        let medium = levels.filter { $0 >= 1 && $0 < 2 }.count
        if levels.isEmpty { return "Mostly moving so far today." }
        if high > 0 { return high == 1 ? "One high-stress hour so far today." : "\(high) high-stress hours so far today." }
        if medium * 2 > levels.count { return "A busy day: mostly medium stress." }
        return "Mostly calm so far today."
    }

    private func bars(_ hours: [StressHour]) -> some View {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Demo.now)
        let nowHour = cal.dateInterval(of: .hour, for: Demo.now)?.start ?? Demo.now
        let maxH: CGFloat = 64
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<24, id: \.self) { i in
                let slot = cal.date(byAdding: .hour, value: i, to: start) ?? start
                let h = hours.first(where: { $0.start == slot })
                let top = UnevenRoundedRectangle(topLeadingRadius: Radius.bar, topTrailingRadius: Radius.bar)
                Group {
                    if let h {
                        if let level = h.level {
                            top.fill(Insights.stressColor(level))
                                .frame(height: max(CGFloat(level / 3) * maxH, 4))
                        } else {
                            top.fill(Theme.graphite2)              // Moving: excluded, neutral
                                .frame(height: maxH * 0.25)
                        }
                    } else if slot > nowHour {
                        top.strokeBorder(Theme.hair, lineWidth: 1)   // still to come
                            .frame(height: 8)
                    } else {
                        Rectangle().fill(Theme.hair).frame(height: 1) // no reading: a gap, not a zero
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .printGrain(amount: 0.03)
        .frame(height: maxH, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stress by hour")
        .accessibilityValue(hours.map { h in
            "\(h.start.formatted(date: .omitted, time: .shortened)) \(h.level.map { Insights.stressWord($0) } ?? Insights.movingWord)"
        }.joined(separator: ", "))
    }

    private var axis: some View {
        let start = Calendar.current.startOfDay(for: Demo.now)
        let marks = [0, 6, 12, 18].compactMap { Calendar.current.date(byAdding: .hour, value: $0, to: start) }
        return HStack(spacing: 0) {
            ForEach(marks, id: \.self) { d in
                Text(d.formatted(.dateTime.hour()))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .typo(.caption).foregroundStyle(Theme.graphite)
        .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: Space.m) {
            item(Theme.good, "Calm")
            item(Theme.limit, "Medium")
            item(Theme.danger, "High")
            item(Theme.graphite2, Insights.movingWord)
        }
        .accessibilityHidden(true)
    }

    private func item(_ c: Color, _ t: String) -> some View {
        HStack(spacing: Space.xs) {
            Circle().fill(c).frame(width: 6, height: 6)
            Text(t).typo(.caption).foregroundStyle(Theme.ink2)
        }
    }
}

// MARK: - Body panels strip ("N to watch" → Body tab)

struct PanelsStrip: View {
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav
    let open: () -> Void

    var body: some View {
        let watch = Panel.allCases.flatMap(\.metrics).filter { health.state($0).isConcern }.count
        Button(action: open) {
            Card {
                CardTitle(title: "Body panels", trailing: watch == 0 ? "All in range" : "\(watch) to watch",
                          coach: CoachTarget(metric: nil, name: "Body panels"))
                HStack(spacing: Space.s) {
                    ForEach(Panel.allCases) { p in
                        let t = tier(p)
                        VStack(alignment: .leading, spacing: Space.s) {
                            Capsule().fill(t?.fill ?? Theme.hair).frame(height: 8)
                            Text(p.short).typo(.caption).foregroundStyle(Theme.ink2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(p.title)
                        .accessibilityValue(t?.word ?? "No reading")
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the Body tab")
        .coachAccessibilityAction { nav.openCoach(about: nil) }
    }

    /// Worst tier among the panel's metrics; nil when nothing in the panel has data.
    private func tier(_ p: Panel) -> StatusTier? {
        let tiers = p.metrics.compactMap { health.state($0).statusTier }
        if tiers.contains(.outOfRange) { return .outOfRange }
        if tiers.contains(.watch) { return .watch }
        return tiers.isEmpty ? nil : .inRange
    }
}

// MARK: - Drift banner (2+ vitals outside the usual range)

struct DriftBanner: View {
    @Environment(HealthStore.self) private var health

    var body: some View {
        let drifting = HealthMonitorCard.vitals.map { health.state($0) }.filter(\.isConcern)
        if drifting.count >= 2 {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.s) {
                    tierDot(.watch)
                    Text("\(drifting.count) signals are outside your usual range")
                        .typo(.headline).foregroundStyle(Theme.ink)
                }
                Text(ListFormatter.localizedString(byJoining: drifting.map { $0.id.info.name }) + ". Your body may need more rest. Consider an easy day.")
                    .typo(.body).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.limitBg, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Health monitor: vitals × 7 nights heat map

/// v1.3: folds to one row ("All vitals in your usual range" + chevron) while no vital is a concern;
/// opens by itself when one drifts. Open/closed is remembered per scene.
struct HealthMonitorCard: View {
    @Environment(HealthStore.self) private var health
    @State private var sheet: MetricState?
    @SceneStorage("today.monitor.open") private var open = false

    static let vitals: [MetricID] = [.restingHR, .hrv, .breathing, .spo2, .skinTemp]

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Demo.now)
        return (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    private enum Cell { case tier(StatusTier), noReading, notSent }

    private func cell(_ s: MetricState, on day: Date) -> Cell {
        if !s.hasData && s.id.isNotSentByGoogle { return .notSent }
        guard let v = s.series.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })?.value else { return .noReading }
        guard let band = s.band else { return .tier(.inRange) }
        let outside = v > band.upperBound || v < band.lowerBound
        guard outside else { return .tier(.inRange) }
        let concern: Bool = {
            guard let higherIsBetter = Insights.direction(s.id) else { return true }
            return (v > band.upperBound) != higherIsBetter
        }()
        guard concern else { return .tier(.inRange) }
        let sd = s.baseline?.sd ?? max((band.upperBound - band.lowerBound) / 2, 0.0001)
        let dist = v > band.upperBound ? (v - band.upperBound) / sd : (band.lowerBound - v) / sd
        return .tier(dist > 1 ? .outOfRange : .watch)
    }

    var body: some View {
        let states = Self.vitals.map { health.state($0) }
        let drifting = states.filter(\.isConcern)
        Group {
            if open || !drifting.isEmpty {
                expanded(states, drifting: drifting)
            } else {
                folded(states)
            }
        }
        .sheet(item: $sheet) { MetricSheet(state: $0) }
        // Auto-open on drift; stays open after it settles until folded again.
        .onChange(of: drifting.isEmpty, initial: true) { _, quiet in
            if !quiet && !open { open = true }
        }
    }

    /// Quiet state: one row, tap to unfold in place.
    private func folded(_ states: [MetricState]) -> some View {
        let shared = states.filter(\.hasData)
        return Button { Motion.animate(Motion.crossfade) { open = true } } label: {
            Card {
                HStack(spacing: Space.s) {
                    if !shared.isEmpty { tierDot(.inRange) }
                    Text(shared.isEmpty ? "Health monitor is waiting for sync" : "All vitals in your usual range")
                        .typo(.headline).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Space.s)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.graphite)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Health monitor. " + (shared.isEmpty ? "Waiting for sync" : "All vitals in your usual range"))
        .accessibilityHint("Shows the last 7 nights for each vital")
    }

    private func expanded(_ states: [MetricState], drifting: [MetricState]) -> some View {
        let shared = states.filter(\.hasData)
        return Card {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                CardTitle(title: "Health monitor",
                          trailing: shared.isEmpty ? "Waiting for sync" : "\(shared.count - drifting.count) of \(shared.count) in range",
                          coach: CoachTarget(metric: nil, name: "Health monitor"))
                if drifting.isEmpty {
                    Button { Motion.animate(Motion.crossfade) { open = false } } label: {
                        Image(systemName: "chevron.up")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.graphite)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .padding(.vertical, -Space.m)
                    .padding(.trailing, -Space.m)
                    .accessibilityLabel("Fold health monitor")
                }
            }
            Text(drifting.isEmpty ? "Your vitals sat in their usual range this week." : "Alerts you when 2 or more vitals drift on the same night.")
                .typo(.body).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: Space.xs, verticalSpacing: Space.xs) {
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    ForEach(days, id: \.self) { d in
                        Text(d.formatted(.dateTime.weekday(.narrow)))
                            .typo(.micro).foregroundStyle(Theme.ink2)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(states) { s in
                    GridRow {
                        Button { sheet = s } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(short(s.id)).typo(.label).foregroundStyle(Theme.ink)
                                if !s.hasData {
                                    Text(s.id.isNotSentByGoogle ? "Not sent" : "No reading")
                                        .typo(.micro).foregroundStyle(Theme.graphite)
                                }
                            }
                            .frame(width: 92, alignment: .leading)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(s.id.info.name)
                        .accessibilityValue(s.hasData ? "\(s.displayText) \(s.id.info.unit), \(s.statusWord)" : (s.id.isNotSentByGoogle ? "Not sent by Google Health" : "No reading"))
                        .accessibilityHint("Shows what it means")
                        ForEach(days, id: \.self) { d in
                            square(cell(s, on: d))
                        }
                    }
                }
            }
            Text(Insights.heatMapLegend + " Not sent means Google Health doesn’t share it.")
                .typo(.caption).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func square(_ c: Cell) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        Group {
            switch c {
            case .tier(let t): shape.fill(t.fill.opacity(t == .inRange ? 0.75 : 1))
            case .notSent: shape.fill(Theme.hair)
            case .noReading: shape.strokeBorder(Theme.hair, lineWidth: 1)
            }
        }
        .frame(height: 20)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func short(_ id: MetricID) -> String {
        switch id {
        case .restingHR: return "Resting HR"
        case .hrv: return "HRV"
        case .breathing: return "Breathing"
        case .spo2: return "Oxygen"
        case .skinTemp: return "Skin temp"
        default: return id.info.name
        }
    }
}

// MARK: - Last night (StageBar → Sleep detail)

struct LastNightCard: View {
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav
    let session: SleepSession

    var body: some View {
        NavigationLink(value: Route.score(.sleep)) {
            Card {
                CardTitle(title: health.isSleepFresh ? "Last night" : "Latest night synced, \(health.sleepDayText)",
                          trailing: "\(session.start.formatted(date: .omitted, time: .shortened))–\(session.end.formatted(date: .omitted, time: .shortened))",
                          coach: CoachTarget(metric: .sleepTotal, name: "Last night"))
                ValueText(value: MetricID.sleepTotal.format(session.asleepMinutes), unit: "asleep", size: .metric)
                StageBar(session: session)
                    .frame(height: 12)
                    .accessibilityHidden(true)
                HStack(alignment: .top, spacing: Space.s) {
                    stage("Deep", .deep)
                    stage("Core", .light)
                    stage("REM", .rem)
                    stage("Awake", .awake)
                }
                if !health.isSleepFresh {
                    NotSentLabel(kind: .waiting)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows sleep details")
        .coachAccessibilityAction { nav.openCoach(about: .sleepTotal) }
    }

    private func stage(_ name: String, _ s: SleepStage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Space.xs) {
                RoundedRectangle(cornerRadius: 1).fill(s.color).frame(width: 8, height: 8)
                Text(name).typo(.caption).foregroundStyle(Theme.ink2)
            }
            Text(MetricID.sleepTotal.format(session.minutes(s)))
                .typo(.label).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sleep debt & consistency

struct SleepBalanceCard: View {
    @Environment(HealthStore.self) private var health
    @State private var info: SleepInfo?

    var body: some View {
        let nights = health.recentNights
        let debt = Insights.sleepDebt(nights)
        let spread = Insights.bedtimeSpread(nights)
        Card {
            HStack(alignment: .top, spacing: 0) {
                tile(title: "Sleep debt",
                     value: nights.isEmpty ? "—" : MetricID.sleepTotal.format(debt),
                     sub: "Last 7 nights vs 8 h",
                     tier: nights.isEmpty ? nil : (debt > 180 ? .outOfRange : (debt > 60 ? .watch : .inRange)),
                     word: debt > 180 ? "Significant" : (debt > 60 ? "Noticeable" : "Fine"),
                     tag: .debt)
                Rectangle().fill(Theme.hair).frame(width: 0.5).padding(.horizontal, Space.l)
                tile(title: "Consistency",
                     value: spread.map { "\(Insights.consistencyScore($0))%" } ?? "—",
                     sub: spread.map { "Bedtime ±\(Int($0.rounded())) min" } ?? "Needs 3 nights",
                     tier: spread.map { $0 > 60 ? .watch : .inRange },
                     word: (spread ?? 0) > 60 ? "Irregular" : ((spread ?? 0) > 30 ? "OK" : "Regular"),
                     tag: .consistency)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        // CoachMark top-right, level with the tile titles (the right tile's title is leading, so the corner is free).
        .overlay(alignment: .topTrailing) {
            CoachMarkSlot(metric: .sleepTotal, name: "Sleep debt and consistency")
                .padding(.top, Space.gutter + 1)
                .padding(.trailing, Space.gutter)
        }
        .sheet(item: $info) { tag in
            if tag == .debt {
                ExplainSheet(title: "Sleep debt", sub: "How much sleep you are missing this week",
                             what: "For each of the last 7 nights, MRH1 adds up how far you were below an 8-hour need. Nights above 8 h don’t cancel debt. Debt builds tiredness and lowers recovery; paying it back takes a few longer nights, not one.",
                             rows: [("Under 1 h", "Fine."), ("1 – 3 h", "Noticeable: aim for earlier nights."), ("Over 3 h", "Significant: expect lower recovery and focus.")])
            } else {
                ExplainSheet(title: "Sleep consistency", sub: "How regular your bedtime is",
                             what: "The spread of your bedtimes over the last 2 weeks. Going to bed at a similar time keeps your body clock steady, which improves sleep quality even when the hours are the same.",
                             rows: [("±30 min or less", "Very regular (80 %+)."), ("±30 – 60 min", "OK."), ("More than ±60 min", "Irregular: like mild jet lag every week.")])
            }
        }
    }

    private func tile(title: String, value: String, sub: String, tier: StatusTier?, word: String, tag: SleepInfo) -> some View {
        Button { info = tag } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.xs) {
                    Text(title).typo(.label).foregroundStyle(Theme.ink2)
                    Image(systemName: "info.circle").font(.footnote).foregroundStyle(Theme.graphite)
                }
                ValueText(value: value, size: .metric)
                if let tier {
                    HStack(spacing: Space.xs) {
                        tierDot(tier)
                        Text(word).typo(.label).foregroundStyle(Theme.ink)
                    }
                }
                Text(sub).typo(.caption).foregroundStyle(Theme.graphite)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Explains \(title.lowercased())")
    }
}

// MARK: - Journal: today's tags + discoveries

struct JournalCard: View {
    @Environment(JournalStore.self) private var journal
    let openSheet: () -> Void

    var body: some View {
        let today = journal.entries(for: Demo.now).sorted()
        let found = journal.discoveries
        Card {
            CardTitle(title: found.isEmpty ? "Journal" : "Discoveries",
                      trailing: today.isEmpty ? "Nothing tagged today" : "\(today.count) tagged today")
            if found.isEmpty {
                Text(journal.progressText.map { $0 + "." } ?? "Tag your days to see what moves your sleep and recovery.")
                    .typo(.body).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: Space.m) {
                    ForEach(found, id: \.self) { line in
                        Text(line).typo(.body).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Patterns in your own data, not causes.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            }
            if !today.isEmpty {
                Text(ListFormatter.localizedString(byJoining: today))
                    .typo(.label).foregroundStyle(Theme.ink2)
            }
            Button(action: openSheet) {
                Text(today.isEmpty ? "Tag today" : "Edit today’s tags")
                    .typo(.label)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, Space.l)
                    .frame(minHeight: 44)
                    .background(Capsule().strokeBorder(Theme.ink.opacity(0.25), lineWidth: 0.5))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressStyle())
        }
    }
}
