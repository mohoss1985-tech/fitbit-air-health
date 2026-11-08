import SwiftUI
import Charts

/// Recovery, Strain and Sleep details (pushed from the Today rings).
/// Score transparency (research/02 Decision 8): every input shows its z-score and its weight.
struct ScoreDetailView: View {
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav
    @Environment(\.dynamicTypeSize) private var typeSize
    let kind: ScoreKind

    @State private var sheet: MetricState?
    @State private var showHow = false
    @State private var pickedDay: Date?
    @State private var pickedTime: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.cardGap) {
                switch kind {
                case .recovery: recoveryBody
                case .strain: strainBody
                case .sleep: sleepBody
                }
                // v1.1: "Ask about this" at the foot (hidden while the coach is off).
                AskCoachRow(name: title) { nav.openCoachSheet(about: kind == .sleep ? .sleepTotal : nil) }
                    .padding(.top, Space.l)
                SheetDisclaimer()
                    .padding(.horizontal, Space.xs)
                    .padding(.top, Space.l)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.section)
        }
        .background(Theme.paper)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { MetricSheet(state: $0) }
    }

    private var title: String {
        switch kind {
        case .recovery: return "Recovery"
        case .strain: return "Strain"
        case .sleep: return "Sleep"
        }
    }

    // MARK: - Shared header

    private func scoreHeader<Center: View>(progress: Double, color: Color, ringName: String,
                                           chip: StatusTier?, headline: String, caption: String,
                                           footnote: String? = nil,
                                           @ViewBuilder center: () -> Center) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.l))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.xl))
        return Card {
            layout {
                TickRing(progress: progress, color: color, size: 132, animateOnAppear: false,
                         accessibilityName: ringName, center: center)
                VStack(alignment: .leading, spacing: Space.s) {
                    if let chip { StatusChip(tier: chip) }
                    Text(headline).typo(.headline).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(caption).typo(.body).foregroundStyle(Theme.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    if let footnote {
                        Text(footnote).typo(.caption).foregroundStyle(Theme.graphite)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func cardTitle(_ text: String, sub: String? = nil, trailing: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(text).typo(.headline).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let sub {
                    Text(sub).typo(.caption).foregroundStyle(Theme.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            if let trailing { Text(trailing).typo(.caption).foregroundStyle(Theme.graphite) }
        }
    }

    // MARK: - Recovery

    private func recoveryTier(_ score: Int) -> StatusTier {
        score >= 67 ? .inRange : (score >= 34 ? .watch : .outOfRange)
    }

    @ViewBuilder private var recoveryBody: some View {
        if let r = health.recovery {
            scoreHeader(progress: Double(r.score) / 100, color: Scores.recoveryColor(r.score),
                        ringName: "Recovery", chip: recoveryTier(r.score),
                        headline: Scores.verdict(r),
                        caption: "How ready your body is today, comparing last night with your own normal.",
                        footnote: r.signalsText.map { "\($0). " + missingNote(r) }) {
                ValueText(value: "\(r.score)", unit: "%", size: .metric)
            }
            contributorsCard(r)
            recoveryHistoryCard
            howComputedCard
        } else {
            scoreHeader(progress: 0, color: Theme.good, ringName: "Recovery", chip: nil,
                        headline: "Calibrating",
                        caption: "Recovery needs a few nights of resting heart rate (or HRV) to learn your normal. Keep wearing the Air at night.") {
                ValueText(value: "—", size: .metric)
            }
            calibratingCard
            recoveryHistoryCard
            howComputedCard
        }
    }

    private func missingNote(_ r: RecoveryResult) -> String {
        let names = r.missingInputs.map { RecoveryWeights.shortName($0) }
        guard !names.isEmpty else { return "" }
        return names.joined(separator: " and ") + (names.count == 1 ? " is" : " are") + " left out."
    }

    // Contributors: diverging bars either side of "your normal", with z-score and weight.

    private func contributorsCard(_ r: RecoveryResult) -> some View {
        let used = r.contributors.reduce(0) { $0 + RecoveryWeights.weight($1.id) }
        return Card(spacing: Space.l) {
            cardTitle("What drove it", sub: "Each signal vs your own normal, sized by its weight.")
            VStack(spacing: Space.xs) {
                normalAxisLabel
                ForEach(r.contributors) { c in
                    Button { sheet = health.state(c.id) } label: {
                        contributorRow(c, share: RecoveryWeights.weight(c.id) / max(used, 0.0001))
                    }
                    .buttonStyle(PressStyle())
                }
                ForEach(r.missingInputs, id: \.self) { id in
                    missingContributorRow(id)
                }
            }
            Text("Right of the line helped your score, left of it pulled it down.")
                .typo(.caption).foregroundStyle(Theme.graphite)
        }
    }

    private var normalAxisLabel: some View {
        HStack {
            Text("Worse").frame(maxWidth: .infinity, alignment: .leading)
            Text("Your normal")
            Text("Better").frame(maxWidth: .infinity, alignment: .trailing)
        }
        .typo(.micro)
        .foregroundStyle(Theme.graphite)
        .accessibilityHidden(true)
    }

    private func contributorRow(_ c: Contributor, share: Double) -> some View {
        let zText = String(format: "%.1f", locale: .current, abs(c.z))
        let side = c.z >= 0.05 ? "better" : (c.z <= -0.05 ? "worse" : "at")
        let zLine = side == "at" ? "At your normal" : "\(zText) SD \(side) than usual"
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(RecoveryWeights.shortName(c.id)).typo(.body).foregroundStyle(Theme.ink)
                Spacer(minLength: Space.s)
                Text(c.valueText).typo(.body).foregroundStyle(Theme.ink)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.graphite2)
            }
            DivergingBar(z: c.z, weight: share)
                .frame(height: 12)
            HStack {
                Text(zLine)
                Spacer(minLength: Space.s)
                Text("Weight \(Int((share * 100).rounded()))\u{00A0}%")
            }
            .typo(.caption)
            .foregroundStyle(Theme.graphite)
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(RecoveryWeights.shortName(c.id)), \(c.valueText)")
        .accessibilityValue("\(zLine), weight \(Int((share * 100).rounded())) percent")
        .accessibilityHint("Shows what it means")
        .accessibilityAddTraits(.isButton)
    }

    private func missingContributorRow(_ id: MetricID) -> some View {
        let s = health.state(id)
        let kind: NotSentKind = id.isNotSentByGoogle ? .notSent : (s.hasData ? .waiting : .noReading)
        let text = s.hasData && s.baseline == nil ? "Learning your normal" : kind.text
        return Button { sheet = s } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(RecoveryWeights.shortName(id)).typo(.body).foregroundStyle(Theme.graphite)
                    Spacer(minLength: Space.s)
                    Text("—").typo(.body).foregroundStyle(Theme.graphite)
                }
                DivergingBar(z: nil, weight: 0).frame(height: 12)
                Text(text + ". Left out, the rest re-weighted.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            }
            .padding(.vertical, Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(RecoveryWeights.shortName(id)), \(text). Not used in today’s score")
        .accessibilityAddTraits(.isButton)
    }

    // 14-day recovery chart.

    private var recoveryDays: [(date: Date, score: Int)] {
        health.history.compactMap { d in d.recovery.map { (Calendar.current.startOfDay(for: d.date), $0) } }
    }

    @ViewBuilder private var recoveryHistoryCard: some View {
        let days = recoveryDays
        Card {
            if days.count >= 2 {
                let avg = Double(days.map(\.score).reduce(0, +)) / Double(days.count)
                cardTitle("Last 14 days",
                          sub: "Average \(Int(avg.rounded())) %, latest \(days.last!.score) %. Scale 0 to 100 %.")
                recoveryChart(days)
                    .frame(height: 168)
            } else {
                cardTitle("Last 14 days")
                Text(days.isEmpty ? "The chart fills in as nights sync and your normal is learned."
                                  : "One night so far. The chart appears after the second.")
                    .typo(.body).foregroundStyle(Theme.graphite)
            }
        }
    }

    private func dayRuns(_ days: [(date: Date, score: Int)]) -> [(Int, [(date: Date, score: Int)])] {
        var runs: [[(date: Date, score: Int)]] = []
        for d in days {
            if let last = runs.last?.last, d.date.timeIntervalSince(last.date) < 36 * 3600 {
                runs[runs.count - 1].append(d)
            } else { runs.append([d]) }
        }
        return Array(runs.enumerated())
    }

    private func recoveryChart(_ days: [(date: Date, score: Int)]) -> some View {
        let picked = pickedDay.flatMap { sel in days.min { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) } }
        let first = days.first!.date, last = days.last!.date
        return Chart {
            ForEach(dayRuns(days), id: \.0) { run in
                ForEach(run.1, id: \.date) { d in
                    LineMark(x: .value("Day", d.date), y: .value("Recovery", d.score), series: .value("Run", run.0))
                        .interpolationMethod(.monotone)
                        .lineStyle(MRHChart.line)
                        .foregroundStyle(Theme.ink)
                }
            }
            ForEach(days, id: \.date) { d in
                let isLast = d.date == last
                PointMark(x: .value("Day", d.date), y: .value("Recovery", d.score))
                    .symbol {
                        Circle()
                            .fill(isLast ? Theme.ember : recoveryTier(d.score).fill)
                            .overlay(Circle().strokeBorder(Theme.card, lineWidth: 2))
                            .frame(width: picked?.date == d.date ? 12 : 9, height: picked?.date == d.date ? 12 : 9)
                    }
                    .accessibilityLabel(d.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .accessibilityValue("\(d.score) percent, \(recoveryTier(d.score).word)")
            }
            if let picked {
                RuleMark(x: .value("Day", picked.date))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.ink)
                    .annotation(position: .top, spacing: Space.xs,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        ChartBubble(title: picked.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                                    value: "\(picked.score)", unit: "%", note: recoveryTier(picked.score).word)
                    }
            }
        }
        .chartXSelection(value: $pickedDay)
        .chartYScale(domain: 0...100)
        .chartXScale(domain: first.addingTimeInterval(-12 * 3600)...last.addingTimeInterval(12 * 3600))
        .chartXAxis {
            AxisMarks(values: [first, last]) { v in
                AxisValueLabel(anchor: v.index == 0 ? .topLeading : .topTrailing) {
                    if let d = v.as(Date.self) {
                        Text(Calendar.current.isDateInToday(d) ? "Today" : d.formatted(.dateTime.day().month(.abbreviated)))
                    }
                }
                .font(Typo.caption.monospacedDigit())
                .foregroundStyle(Theme.graphite)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { _ in
                AxisGridLine(stroke: MRHChart.grid).foregroundStyle(Theme.graphite2)
                AxisValueLabel().font(Typo.caption.monospacedDigit()).foregroundStyle(Theme.graphite)
            }
        }
        .mrhAxes()
        .sensoryFeedback(.selection, trigger: picked?.date)
        .accessibilityLabel("Recovery over the last 14 days")
    }

    // Calibrating checklist.

    private var calibratingCard: some View {
        Card {
            cardTitle("Learning your normal", sub: "Recovery starts once a heart signal has 3 nights of history.")
            VStack(spacing: 0) {
                ForEach(Array(RecoveryResult.allInputs.enumerated()), id: \.element) { i, id in
                    if i > 0 { Rectangle().fill(Theme.hair).frame(height: 0.5) }
                    let s = health.state(id)
                    let ready = s.baseline != nil
                    let status: String = ready ? "Ready"
                        : id.isNotSentByGoogle && !s.hasData ? NotSentKind.notSent.text
                        : s.hasData ? "\(s.series.count) of 4 nights"
                        : NotSentKind.waiting.text
                    HStack(spacing: Space.m) {
                        Image(systemName: ready ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(ready ? Theme.good : Theme.graphite2)
                        Text(RecoveryWeights.shortName(id)).typo(.body).foregroundStyle(Theme.ink)
                        Spacer(minLength: Space.s)
                        Text(status).typo(.caption).foregroundStyle(Theme.graphite)
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // How it's computed.

    private var howComputedCard: some View {
        Card(spacing: 0) {
            Button {
                Motion.animate(Motion.morph) { showHow.toggle() }
            } label: {
                HStack {
                    Text("How it’s computed").typo(.headline).foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.graphite)
                        .rotationEffect(.degrees(showHow ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityValue(showHow ? "Expanded" : "Collapsed")

            if showHow {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text("Each signal is compared with your own normal: how many standard deviations (SD) it sits above or below your average, capped at 3.")
                    VStack(spacing: Space.s) {
                        ForEach(RecoveryResult.allInputs, id: \.self) { id in
                            HStack {
                                Text(RecoveryWeights.shortName(id)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(Int((RecoveryWeights.weight(id) * 100).rounded()))\u{00A0}%").foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    .padding(Space.l)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    Text("Missing signals are left out and the others re-weighted, so HRV’s share goes to the rest when Google Health doesn’t send it.")
                    Text("The weighted average passes through a smooth curve to 0–100 %. 67 and up is In range, 34–66 is Watch, below 34 is Out of range.")
                    Text("Sleep compares last night with an 8 h need. Your normal needs 3 nights, and gets steadier up to 14.")
                }
                .typo(.body)
                .foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.m)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Strain

    @ViewBuilder private var strainBody: some View {
        let s = health.strain
        let target = Scores.todayStrainTarget(health)
        scoreHeader(progress: (s?.value ?? 0) / 21, color: Theme.ember, ringName: "Strain", chip: nil,
                    headline: strainAdvice(s?.value, target: target),
                    caption: "All-day load on your heart, 0–21. Each step up is harder: 10–13 moderate, 14–17 high, 18+ all out.") {
            ValueText(value: s.map { String(format: "%.1f", locale: .current, $0.value) } ?? "—", unit: "/\u{00A0}21", size: .metric)
        }

        Card {
            cardTitle("Today’s target", trailing: "\(Int(target.lowerBound))–\(Int(target.upperBound))")
            StrainGauge(value: s?.value ?? 0, target: target)
            Text("Set by your recovery. The two ink ticks mark the target zone.")
                .typo(.caption).foregroundStyle(Theme.graphite)
        }

        if health.todayHeartRate.count >= 2 {
            hrTodayCard
        } else {
            Card {
                cardTitle("Heart rate today")
                NotSentLabel(kind: .waiting)
                Text("Readings arrive in batches from Google Health.")
                    .typo(.body).foregroundStyle(Theme.graphite)
            }
        }

        if let s { zonesCard(s) }

        if !health.todayWorkouts.isEmpty {
            Card(spacing: 0) {
                cardTitle("Workouts today")
                    .padding(.bottom, Space.s)
                ForEach(Array(health.todayWorkouts.enumerated()), id: \.element.id) { i, w in
                    if i > 0 { Rectangle().fill(Theme.hair).frame(height: 0.5) }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).typo(.body).foregroundStyle(Theme.ink)
                            Text(w.start.formatted(date: .omitted, time: .shortened))
                                .typo(.caption).foregroundStyle(Theme.graphite)
                        }
                        Spacer()
                        ValueText(value: "\(Int(w.minutes.rounded()))", unit: "min", size: .headline)
                    }
                    .padding(.vertical, Space.m)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func strainAdvice(_ v: Double?, target: ClosedRange<Double>) -> String {
        guard let v else { return "No heart rate yet today." }
        if v < target.lowerBound {
            return String(format: "About %.0f to go to reach today’s target.", locale: .current, target.lowerBound - v)
        }
        if v <= target.upperBound { return "You’re in today’s target zone." }
        return "Past today’s target. Ease off for the rest of the day."
    }

    private var hrTodayCard: some View {
        let pts = health.todayHeartRate.sorted { $0.date < $1.date }
        let lo = (pts.map(\.bpm).min() ?? 50), hi = (pts.map(\.bpm).max() ?? 120)
        let floorY = (lo - 8).rounded(.down)
        let domain = floorY...(hi + 8).rounded(.up)
        let peak = pts.max { $0.bpm < $1.bpm }
        let runs = hrRuns(pts)
        let picked = pickedTime.flatMap { nearest(pts, to: $0) }
        let lastPt = pts.last
        return Card {
            cardTitle("Heart rate today",
                      sub: peak.map { "Peak \(Int($0.bpm.rounded()))\u{00A0}bpm at \($0.date.formatted(date: .omitted, time: .shortened)). Beats per minute." })
            Chart {
                ForEach(runs, id: \.0) { run in
                    ForEach(run.1) { p in
                        AreaMark(x: .value("Time", p.date),
                                 yStart: .value("Floor", floorY),
                                 yEnd: .value("bpm", p.bpm),
                                 series: .value("Run", run.0))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(.grainedArea(Theme.ember))
                        LineMark(x: .value("Time", p.date), y: .value("bpm", p.bpm), series: .value("Run", run.0))
                            .interpolationMethod(.monotone)
                            .lineStyle(MRHChart.line)
                            .foregroundStyle(Theme.ember)
                    }
                }
                if let lastPt {
                    PointMark(x: .value("Time", lastPt.date), y: .value("bpm", lastPt.bpm))
                        .symbol {
                            Circle().fill(Theme.ember)
                                .overlay(Circle().strokeBorder(Theme.card, lineWidth: 2))
                                .frame(width: 10, height: 10)
                        }
                }
                if let picked {
                    RuleMark(x: .value("Time", picked.date))
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.ink)
                        .annotation(position: .top, spacing: Space.xs,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ChartBubble(title: picked.date.formatted(date: .omitted, time: .shortened),
                                        value: "\(Int(picked.bpm.rounded()))", unit: "bpm", note: nil)
                        }
                }
            }
            .chartXSelection(value: $pickedTime)
            .chartYScale(domain: domain)
            .mrhAxes(xCount: 4)
            .frame(height: 188)
            .sensoryFeedback(.selection, trigger: picked.map { Int($0.date.timeIntervalSince1970 / 300) })
            .accessibilityLabel("Heart rate today")
            .accessibilityValue("From \(Int(lo)) to \(Int(hi)) beats per minute" + (lastPt.map { ", latest \(Int($0.bpm.rounded()))" } ?? ""))
        }
    }

    /// Runs of samples with no gap longer than 15 min, so gaps stay gaps.
    private func hrRuns(_ pts: [HRPoint]) -> [(Int, [HRPoint])] {
        var runs: [[HRPoint]] = []
        for p in pts {
            if let last = runs.last?.last, p.date.timeIntervalSince(last.date) <= 15 * 60 {
                runs[runs.count - 1].append(p)
            } else { runs.append([p]) }
        }
        return Array(runs.enumerated())
    }

    private func nearest(_ pts: [HRPoint], to t: Date) -> HRPoint? {
        guard !pts.isEmpty else { return nil }
        var lo = 0, hi = pts.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if pts[mid].date < t { lo = mid + 1 } else { hi = mid }
        }
        if lo > 0, abs(pts[lo - 1].date.timeIntervalSince(t)) < abs(pts[lo].date.timeIntervalSince(t)) { return pts[lo - 1] }
        return pts[lo]
    }

    private func zonesCard(_ s: StrainResult) -> some View {
        let maxMin = max(s.zoneMinutes.max() ?? 1, 1)
        let total = s.zoneMinutes.reduce(0, +)
        return Card(spacing: Space.l) {
            cardTitle("Time in heart-rate zones",
                      sub: String(format: "%.0f min above 50 %% of your max heart rate (%.0f bpm, from your age).", locale: .current, total, s.maxHR))
            VStack(spacing: Space.m) {
                ForEach(0..<5, id: \.self) { i in
                    let m = s.zoneMinutes[i]
                    HStack(spacing: Space.m) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Zone \(i + 1)").typo(.label).foregroundStyle(Theme.ink)
                            Text("\(50 + i * 10)–\(60 + i * 10)\u{00A0}%").typo(.caption).foregroundStyle(Theme.graphite)
                        }
                        .frame(width: 64, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: Radius.bar).fill(Theme.hair.opacity(0.6))
                                RoundedRectangle(cornerRadius: Radius.bar)
                                    .fill(Color.oklabMix(Theme.peach, Theme.ember, t: 0.25 + Double(i) * 0.1875))
                                    .frame(width: m > 0 ? max(geo.size.width * m / maxMin, 3) : 0)
                                    .printGrain(amount: 0.03)
                            }
                        }
                        .frame(height: 12)
                        ValueText(value: "\(Int(m.rounded()))", unit: "min", size: .headline)
                            .frame(minWidth: 64, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Zone \(i + 1), \(50 + i * 10) to \(60 + i * 10) percent of max")
                    .accessibilityValue("\(Int(m.rounded())) minutes")
                }
            }
        }
    }

    // MARK: - Sleep

    @ViewBuilder private var sleepBody: some View {
        if let night = health.lastSleep {
            let times = "\(night.start.formatted(date: .omitted, time: .shortened)) – \(night.end.formatted(date: .omitted, time: .shortened))"
            let eff = Int((night.efficiency * 100).rounded())
            scoreHeader(progress: Double(health.sleepScore ?? 0) / 100, color: Theme.iris, ringName: "Sleep score",
                        chip: nil,
                        headline: "\(MetricID.sleepTotal.format(night.asleepMinutes)) asleep",
                        caption: "\(times). \(eff)\u{00A0}% of your time in bed was sleep.",
                        footnote: health.isSleepFresh ? nil
                            : "Night ending \(health.sleepDayText). Last night is waiting for sync.") {
                ValueText(value: health.sleepScore.map { "\($0)" } ?? "—", size: .metric)
            }

            Card(spacing: Space.l) {
                cardTitle("Your night", sub: nightTakeaway(night))
                if night.hasStages {
                    Hypnogram(session: night).frame(height: 152)
                    StageTotals(session: night)
                } else {
                    StageBar(session: night).frame(height: 12)
                    Text("Stages weren’t sent for this night, only time asleep and awake.")
                        .typo(.body).foregroundStyle(Theme.graphite)
                }
            }

            Card(padding: Space.gutter, spacing: 0) {
                ForEach(Array([MetricID.sleepTotal, .deepSleep, .remSleep, .awake].enumerated()), id: \.element) { i, id in
                    if i > 0 { Rectangle().fill(Theme.hair).frame(height: 0.5) }
                    MetricRow(id: id)
                }
            }
        } else {
            scoreHeader(progress: 0, color: Theme.iris, ringName: "Sleep score", chip: nil,
                        headline: NotSentKind.waiting.text,
                        caption: "Last night hasn’t reached Apple Health yet. Google Health sends sleep in batches: open Google Health, let it sync, then pull down here.") {
                ValueText(value: "—", size: .metric)
            }
        }
    }

    private func nightTakeaway(_ n: SleepSession) -> String {
        let restorative = n.minutes(.deep) + n.minutes(.rem)
        guard n.asleepMinutes > 0 else { return "Stages through the night." }
        let pct = Int((restorative / n.asleepMinutes * 100).rounded())
        return "Deep and REM made up \(pct)\u{00A0}% of your sleep. About 40\u{00A0}% is a good night."
    }
}

// MARK: - Recovery weights (mirror Scores.recovery; Scores doesn't expose them)

private enum RecoveryWeights {
    static func weight(_ id: MetricID) -> Double {
        switch id {
        case .hrv: return 0.40
        case .restingHR: return 0.25
        case .sleepTotal: return 0.20
        case .breathing: return 0.15
        default: return 0
        }
    }

    static func shortName(_ id: MetricID) -> String {
        switch id {
        case .hrv: return "HRV"
        case .restingHR: return "Resting heart rate"
        case .sleepTotal: return "Sleep vs need"
        case .breathing: return "Breathing rate"
        default: return id.info.name
        }
    }
}

// MARK: - Diverging contributor bar

/// Paper track, a hair centre tick = "your normal", a bar out to |z| / 3 of the half-width.
/// Bar thickness scales with the signal's weight, so heavy inputs read heavier.
private struct DivergingBar: View {
    let z: Double?
    let weight: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let half = w / 2
            let thick = max(4, min(h, 4 + (h - 4) * CGFloat(min(weight / 0.5, 1))))
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.paper)
                    .overlay(Capsule().strokeBorder(Theme.hair, lineWidth: 0.5))
                    .frame(height: 6)
                    .position(x: half, y: h / 2)
                if let z {
                    let len = max(half * CGFloat(min(abs(z), 3) / 3), 3)
                    RoundedRectangle(cornerRadius: Radius.bar)
                        .fill(color(z))
                        .frame(width: len, height: thick)
                        .position(x: z >= 0 ? half + len / 2 : half - len / 2, y: h / 2)
                }
                Rectangle().fill(Theme.ink).frame(width: 1, height: h)
                    .position(x: half, y: h / 2)
            }
        }
        .accessibilityHidden(true)
    }

    private func color(_ z: Double) -> Color {
        if z >= 0 { return Theme.good }
        return z <= -2 ? Theme.danger : Theme.limit
    }
}

// MARK: - Scrub bubble

/// Value bubble for drag-select on detail charts (card fill, hair stroke, ink value).
struct ChartBubble: View {
    let title: String
    let value: String
    let unit: String
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).typo(.caption).foregroundStyle(Theme.graphite)
            ValueText(value: value, unit: unit, size: .headline)
            if let note { Text(note).typo(.micro).foregroundStyle(Theme.graphite) }
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(Theme.hair, lineWidth: 0.5))
    }
}
