import SwiftUI

/// Live tab (DESIGN_SPEC §4, GOAL Done #3). "Latest truth", not fake real time:
/// the newest heart-rate sample, how old it is (always visible), history for Live · 1H · 24H ·
/// 7D · 30D with min · avg · max, today so far, and last night's breathing and SpO2.
struct LiveView: View {
    @Environment(LiveStore.self) private var live
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var userPickedRange = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header
                chartCard
                todayCard
                lastNightCard
                footer
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .refreshable {
            live.attach(health: health)
            await live.refresh()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { live.start(health: health) }
        .onChange(of: live.latestSampleDate, initial: true) { _, _ in autoPickRange() }
        .onChange(of: health.lastRefresh) { _, _ in live.attach(health: health) }
    }

    // MARK: - Header (orbs, big number, ticker)

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack {
                RoundIconButton(systemName: "line.3.horizontal", label: "Menu") { nav.showMenu = true }
                Spacer()
                Text("Live").typo(.headline).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                // Balances the menu button so the title stays centred.
                Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    Text("Heart rate").typo(.label).foregroundStyle(Theme.ink2)
                    if live.latestSource == .bluetooth { BluetoothBadge() }
                    if live.mode.isDemo { SampleDataChip() }
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(live.latestBPM.map { "\(Int($0.rounded()))" } ?? "—")
                        .typo(.display)
                        .foregroundStyle(live.latestBPM == nil ? Theme.graphite : Theme.ink)
                        .contentTransition(.numericText(value: live.latestBPM ?? 0))
                        .animation(Motion.morph, value: live.latestBPM)
                    if live.latestBPM != nil {
                        Text("bpm").unitStyle()
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Latest heart rate")
                .accessibilityValue(live.latestBPM.map { "\(Int($0.rounded())) beats per minute" } ?? "No reading yet")

                ticker
                if let r = restingContext {
                    Text(r).typo(.caption).foregroundStyle(Theme.graphite)
                }
            }
        }
        .padding(.top, Space.s)
        .background(alignment: .top) {
            OrbBackground(status: nil, evening: isEvening, pulse: live.pulse)
                .frame(height: 480)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.6),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(.horizontal, -Space.gutter)
                .padding(.top, -60)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// SF Mono, ticks every second, always visible. Yellow chip once the feed is hours old.
    @ViewBuilder private var ticker: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = live.mode.isDemo ? live.now : ctx.date
            HStack(spacing: Space.s) {
                Text(tickerText(now: now))
                    .typo(.mono)
                    .foregroundStyle(Theme.ink2)
                    .monospacedDigit()
                if isStale(now: now) {
                    FreshnessChip(date: live.lastDelivery ?? live.latestSampleDate,
                                  verb: live.lastDelivery == nil ? "Synced" : "Checked")
                }
            }
            .accessibilityElement(children: .combine)
        }
        SyncNowButton(date: live.latestSampleDate, checked: health.lastRefresh)
    }

    private func tickerText(now: Date) -> String {
        guard let d = live.latestSampleDate else {
            return live.mode.isDemo ? "Waiting for sample data" : "Waiting for sync"
        }
        let s = Int(max(0, now.timeIntervalSince(d)))
        if s < 60 { return "Latest sample \(s) s ago" }
        return "Latest sample " + LiveStore.ago(d, now: now)
    }

    private func isStale(now: Date) -> Bool {
        guard !live.mode.isDemo else { return false }
        guard let d = live.latestSampleDate else { return true }
        return now.timeIntervalSince(d) > 3 * 3600
    }

    private var restingContext: String? {
        guard let bpm = live.latestBPM, let rest = health.state(.restingHR).latest?.value else { return nil }
        let diff = Int((bpm - rest).rounded())
        if abs(diff) <= 3 { return "Close to your resting \(Int(rest.rounded())) bpm" }
        return diff > 0 ? "\(diff) above your resting \(Int(rest.rounded())) bpm"
                        : "\(-diff) below your resting \(Int(rest.rounded())) bpm"
    }

    private var isEvening: Bool {
        let h = Calendar.current.component(.hour, from: live.mode.isDemo ? live.now : Date())
        return h >= 20 || h < 5
    }

    // MARK: - Chart card

    private var chartCard: some View {
        @Bindable var live = live
        let stats = live.summary(live.selectedRange)
        let model = LiveChartModel(stats: stats, shades: shades, usual: usualDailyBand)
        return Card(spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(chartTitle(stats)).typo(.headline).foregroundStyle(Theme.ink)
                Text(chartSubtitle(live.selectedRange)).typo(.caption).foregroundStyle(Theme.graphite)
            }
            .accessibilityElement(children: .combine)

            ZStack {
                if model.hasData {
                    LiveChart(model: model, pulse: live.pulse)
                } else {
                    emptyChart
                }
            }
            .id(live.selectedRange)
            .transition(.opacity)
            .animation(Motion.crossfade, value: live.selectedRange)

            PillPicker(selection: Binding(get: { live.selectedRange },
                                          set: { userPickedRange = true; live.selectedRange = $0 }),
                       options: LiveRange.allCases) { $0.rawValue }

            statsStrip(stats)
        }
    }

    /// Opening on an empty "Live" window looks broken when Google Health last synced hours ago,
    /// so until the user picks a range we open on the newest window that actually has samples.
    private func autoPickRange() {
        guard !userPickedRange, !live.mode.isDemo, let d = live.latestSampleDate else { return }
        let age = Date().timeIntervalSince(d)
        let pick: LiveRange = age < 30 * 60 ? .live : age < 3600 ? .h1 : age < 20 * 3600 ? .h24 : .d7
        if live.selectedRange != pick { live.selectedRange = pick }
    }

    private var emptyChart: some View {
        VStack(spacing: Space.s) {
            Image(systemName: "clock").font(.system(size: 17, weight: .regular)).foregroundStyle(Theme.graphite)
            Text(live.latestSampleDate == nil ? "Waiting for sync" : "No heart rate in this range yet")
                .typo(.headline).foregroundStyle(Theme.ink)
            Text("Google Health sends readings in batches. They show up here as soon as they reach Apple Health.")
                .typo(.caption).foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.horizontal, Space.l)
        .accessibilityElement(children: .combine)
    }

    private func chartTitle(_ s: RangeStats) -> String {
        guard let lo = s.min, let hi = s.max else { return "Heart rate" }
        switch s.range {
        case .live: return "Between \(Int(lo.rounded())) and \(Int(hi.rounded())) bpm in the last 30 min"
        case .h1: return "Between \(Int(lo.rounded())) and \(Int(hi.rounded())) bpm this hour"
        case .h24: return "Between \(Int(lo.rounded())) and \(Int(hi.rounded())) bpm today"
        case .d7, .d30:
            guard let u = usualDailyBand, let last = s.buckets.last else { return "Daily heart rate range" }
            if last.avg > u.upperBound { return "Today's average is above your usual" }
            if last.avg < u.lowerBound { return "Today's average is below your usual" }
            return "Daily average within your usual range"
        }
    }

    private func chartSubtitle(_ r: LiveRange) -> String {
        switch r {
        case .live: return "Every sample, beats per minute"
        case .h1: return "Minute averages, beats per minute"
        case .h24: return "Hourly averages, sleep and workouts shaded"
        case .d7, .d30: return "Lowest to highest each day, average line, band is your usual"
        }
    }

    private func statsStrip(_ s: RangeStats) -> some View {
        HStack(alignment: .top, spacing: Space.s) {
            statCell(s.min, "Lowest")
            statCell(s.avg, "Average")
            statCell(s.max, "Highest")
        }
    }

    private func statCell(_ v: Double?, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ValueText(value: v.map { "\(Int($0.rounded()))" } ?? "—", unit: "bpm", size: .headline)
                .animation(Motion.crossfade, value: v)
            Text(label).typo(.caption).foregroundStyle(Theme.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(v.map { "\(Int($0.rounded())) beats per minute" } ?? "No reading")
    }

    /// Sleep window and today's workouts, for the 24H shading.
    private var shades: [LiveChartShade] {
        var out: [LiveChartShade] = []
        if let s = health.lastSleep {
            out.append(LiveChartShade(kind: .sleep, start: s.start, end: s.end))
        } else if let w = live.lastNight.window {
            out.append(LiveChartShade(kind: .sleep, start: w.start, end: w.end))
        }
        for w in health.todayWorkouts {
            out.append(LiveChartShade(kind: .workout, start: w.start, end: w.start.addingTimeInterval(w.minutes * 60)))
        }
        return out
    }

    /// Your usual daily average heart rate: mean ± 1 SD of the last 30 days, excluding today.
    private var usualDailyBand: ClosedRange<Double>? {
        let days = live.summary(.d30).buckets.dropLast().map(\.avg)
        guard days.count >= 5 else { return nil }
        let mean = days.reduce(0, +) / Double(days.count)
        let sd = (days.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(days.count)).squareRoot()
        let half = max(sd, 2)
        return (mean - half)...(mean + half)
    }

    // MARK: - So far today

    private var todayCard: some View {
        let t = live.today
        let target = Scores.strainTarget(health.recovery)
        let steps = t.steps ?? health.stepsToday
        let energy = t.energy ?? health.activeEnergyToday
        return VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("So far today")
            Card(spacing: 0) {
                TodayRow(title: "Strain",
                         detail: "Target \(fmtTarget(target.lowerBound))–\(fmtTarget(target.upperBound)) today",
                         value: t.strain.map { fmt1($0.value) }, unit: "of 21",
                         progress: t.strain.map { $0.value / 21 }, color: Theme.ember,
                         marks: [target.lowerBound / 21, target.upperBound / 21],
                         missing: "Waiting for sync")
                divider
                stressRow(t.stressNow)
                divider
                TodayRow(title: "Steps",
                         detail: t.stepsLastHour.map { "\(Int($0.rounded()).formatted()) in the last hour" } ?? usualText(.steps),
                         value: steps.map { Int($0.rounded()).formatted() }, unit: "",
                         progress: progress(steps, of: .steps, fallback: 10_000), color: Theme.ink,
                         missing: "Waiting for sync")
                divider
                TodayRow(title: "Active energy",
                         detail: usualText(.energy),
                         value: energy.map { Int($0.rounded()).formatted() }, unit: "kcal",
                         progress: progress(energy, of: .energy, fallback: 500), color: Theme.ink,
                         missing: "Waiting for sync")
            }
        }
    }

    private func stressRow(_ s: StressHour?) -> some View {
        let level = s?.level
        return TodayRow(title: "Stress now",
                        detail: s.map { "Heart rate above resting while still, \($0.start.formatted(date: .omitted, time: .shortened))" }
                            ?? "Heart rate above resting while still",
                        value: level.map { Insights.stressWord($0) }, unit: "",
                        progress: level.map { $0 / 3 }, color: level.map { Insights.stressColor($0) } ?? Theme.graphite2,
                        missing: s == nil ? "Waiting for sync" : Insights.movingWord)
    }

    private func usualText(_ id: MetricID) -> String {
        guard let m = health.state(id).baseline?.mean else { return "Updates as it syncs" }
        return "Your usual day is \(id.format(m))" + (id.info.unit.isEmpty ? "" : " " + id.info.unit)
    }

    private func progress(_ v: Double?, of id: MetricID, fallback: Double) -> Double? {
        guard let v else { return nil }
        let goal = health.state(id).baseline?.mean ?? fallback
        return goal > 0 ? v / goal : nil
    }

    private var divider: some View {
        Rectangle().fill(Theme.hair).frame(height: 0.5).padding(.vertical, Space.xs)
    }

    // MARK: - Last night

    private var lastNightCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Last night")
            Card(spacing: 0) {
                NightRow(state: health.state(.breathing), override: live.lastNight.breathing,
                         title: "Breathing rate", unit: "/min")
                divider
                NightRow(state: health.state(.spo2), override: live.lastNight.spo2,
                         title: "Blood oxygen", unit: "%")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Readings arrive in batches from Google Health. Fitbit Air has no blood-pressure sensor.")
            Text("Wellness estimates, not medical advice.")
        }
        .typo(.caption)
        .foregroundStyle(Theme.graphite)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fmt1(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1))) }
    /// Targets are whole numbers most of the time: "14–17", not "14,0–17,0".
    private func fmtTarget(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(0...1))) }
}

// MARK: - Rows

/// One "so far today" row: name + context on the left, value + thin arc on the right.
private struct TodayRow: View {
    let title: String
    let detail: String
    let value: String?
    let unit: String
    let progress: Double?
    let color: Color
    var marks: [Double] = []
    let missing: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.m))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).typo(.body).foregroundStyle(Theme.ink)
                Text(detail).typo(.caption).foregroundStyle(Theme.graphite)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Space.m) {
                if let value {
                    ValueText(value: value, unit: unit, size: .headline)
                } else if missing == NotSentKind.waiting.short {
                    NotSentLabel(kind: .waiting, short: true)
                } else {
                    Text(missing).typo(.label).foregroundStyle(Theme.graphite)
                }
                ThinArc(progress: progress, color: color, marks: marks)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.vertical, Space.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([value.map { unit.isEmpty ? $0 : "\($0) \(unit)" } ?? missing, detail].joined(separator: ", "))
    }
}

/// Last-night vital on the baseline ribbon.
private struct NightRow: View {
    let state: MetricState
    let override: Double?
    let title: String
    let unit: String

    private var value: Double? { override ?? state.latest?.value }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).typo(.body).foregroundStyle(Theme.ink)
                    Text(state.baseline == nil ? state.yourRangeText : "Your usual " + state.yourRangeText)
                        .typo(.caption).foregroundStyle(Theme.graphite)
                }
                Spacer(minLength: Space.s)
                if let v = value {
                    ValueText(value: state.id.format(v), unit: unit, size: .headline)
                } else {
                    NotSentLabel(kind: .waiting, short: true)
                }
            }
            if value != nil {
                if override == nil || override == state.latest?.value {
                    BaselineRibbon(state: state)
                } else {
                    BaselineRibbon(value: value, band: state.band)
                }
            }
        }
        .padding(.vertical, Space.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value.map { "\(state.id.format($0)) \(unit == "%" ? "percent" : "per minute"), \(state.directionText)" }
                            ?? "Waiting for sync")
    }
}

// MARK: - Small pieces

/// Thin 300° progress arc (3 pt), hair track, optional target ticks. Over 100 % stays full.
private struct ThinArc: View {
    let progress: Double?
    let color: Color
    var marks: [Double] = []

    private let sweep = 300.0
    private var start: Double { 90 + (360 - sweep) / 2 }

    var body: some View {
        ZStack {
            arc(1).stroke(Theme.hair, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            if let p = progress {
                arc(min(max(p, 0.001), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .animation(Motion.morph, value: p)
            }
            ForEach(marks, id: \.self) { m in
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 1.5, height: 6)
                    .offset(y: -11)
                    .rotationEffect(.degrees(start + sweep * min(max(m, 0), 1) + 90))
            }
        }
        .accessibilityHidden(true)
    }

    private func arc(_ f: Double) -> Path {
        Path { p in
            p.addArc(center: CGPoint(x: 14, y: 14), radius: 11,
                     startAngle: .degrees(start), endAngle: .degrees(start + sweep * f), clockwise: false)
        }
    }
}

/// Shown only while LiveStore's Bluetooth source is feeding the number.
private struct BluetoothBadge: View {
    var body: some View {
        HStack(spacing: Space.xs) {
            Circle().fill(Theme.good).frame(width: 6, height: 6)
            Text("Bluetooth live").typo(.micro)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Space.s)
        .padding(.vertical, 2)
        .background(Theme.card.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(Theme.hair, lineWidth: 0.5))
        .accessibilityLabel("Live from your band over Bluetooth")
    }
}

/// Honest marker while demo data is on (DESIGN_SPEC §7).
private struct SampleDataChip: View {
    var body: some View {
        Text(Demo.chipText)
            .typo(.micro)
            .foregroundStyle(Theme.ink2)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 2)
            .background(Theme.card.opacity(0.7), in: Capsule())
            .overlay(Capsule().stroke(Theme.hair, lineWidth: 0.5))
    }
}
