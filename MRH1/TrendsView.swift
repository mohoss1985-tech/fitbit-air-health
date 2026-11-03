import SwiftUI
import Charts

/// Trends: Apple-Trends grammar. One takeaway sentence per metric, 14 grey bars,
/// the week-before average against the last-7-days average. Changed trends first,
/// the steady rest behind "All metrics". Then the weekly report, tags vs recovery, body age.
struct TrendsView: View {
    @Environment(HealthStore.self) private var health
    @Environment(JournalStore.self) private var journal
    @Environment(AppNav.self) private var nav
    @State private var sheet: MetricState?
    @State private var showAll = false

    /// v0.4 order, kept for the "All metrics" list.
    private let order: [MetricID] = [.restingHR, .hrv, .breathing, .sleepTotal, .deepSleep, .remSleep,
                                     .sleepingHR, .steps, .energy, .workoutMinutes, .spo2, .skinTemp, .awake]

    var body: some View {
        let trends = order.compactMap { id in Insights.trend(health.state(id)) }
        let changed = trends.filter(TrendCopy.changed).sorted { TrendCopy.magnitude($0) > TrendCopy.magnitude($1) }
        let steady = trends.filter { !TrendCopy.changed($0) }
        let noTrend = order.filter { id in !trends.contains { $0.id == id } }

        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                Text("Last 7 days compared with the 7 before.")
                    .typo(.body).foregroundStyle(Theme.graphite)
                    .padding(.bottom, -Space.l)

                if trends.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel(changed.isEmpty ? "This week" : "What changed")
                        if changed.isEmpty {
                            Card {
                                Text("Nothing moved meaningfully this week.").typo(.headline).foregroundStyle(Theme.ink)
                                Text("Every metric is within 3% of the week before.")
                                    .typo(.body).foregroundStyle(Theme.graphite)
                            }
                        }
                        ForEach(changed) { t in trendButton(t) }
                        allMetrics(steady: steady, noTrend: noTrend)
                    }
                }

                if health.weekly != nil {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel("Your week")
                        WeeklyReportCard()
                    }
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    SectionLabel("Tags and recovery")
                    tagsCard
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    SectionLabel("Body age")
                    BodyAgeCard()
                }

                Text("Wellness estimates, not medical advice.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.xxl)
        }
        .background(Theme.paper)
        .navigationTitle("Trends")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { MenuButton(inToolbar: true) }
        }
        .refreshable { await health.refresh() }
        .sheet(item: $sheet) { MetricSheet(state: $0) }
    }

    // MARK: Empty / early state

    private var emptyState: some View {
        let days = MetricID.allCases.map { health.state($0).baselineDays }.max() ?? 0
        return Card {
            Text("Trends need two weeks of data").typo(.headline).foregroundStyle(Theme.ink)
            Text("Keep wearing your band day and night. Comparisons appear once there are two weeks to compare.")
                .typo(.body).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
            Text("Early read: \(min(days, MetricState.fullBaselineDays)) of \(MetricState.fullBaselineDays) baseline days.")
                .typo(.label).foregroundStyle(Theme.ink)
        }
    }

    // MARK: All metrics disclosure

    @ViewBuilder
    private func allMetrics(steady: [Insights.Trend], noTrend: [MetricID]) -> some View {
        let count = steady.count + noTrend.count
        if count > 0 {
            Button {
                Motion.animate(Motion.morph) { showAll.toggle() }
            } label: {
                HStack(spacing: Space.s) {
                    Text("All metrics").typo(.headline).foregroundStyle(Theme.ink)
                    Spacer(minLength: Space.s)
                    Text(steady.isEmpty ? "\(count) more" : "\(steady.count) steady")
                        .typo(.label).foregroundStyle(Theme.graphite)
                    Image(systemName: "chevron.down")
                        .font(Typo.label)
                        .foregroundStyle(Theme.graphite)
                        .rotationEffect(.degrees(showAll ? 180 : 0))
                }
                .padding(.horizontal, Space.gutter)
                .frame(minHeight: 56)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityValue(showAll ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows the metrics that held steady")

            if showAll {
                ForEach(steady) { t in trendButton(t) }
                    .transition(.opacity)
                if !noTrend.isEmpty {
                    Card(spacing: 0) {
                        ForEach(Array(noTrend.enumerated()), id: \.element) { i, id in
                            missingRow(id, last: i == noTrend.count - 1)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private func missingRow(_ id: MetricID, last: Bool) -> some View {
        let s = health.state(id)
        let kind: NotSentKind = (id.isNotSentByGoogle && !s.hasData) ? .notSent : (s.hasData ? .noReading : .waiting)
        return Button { sheet = s } label: {
            HStack(spacing: Space.s) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(id.info.name).typo(.label).foregroundStyle(Theme.ink)
                    if s.hasData {
                        Text("Needs two weeks to compare.").typo(.caption).foregroundStyle(Theme.graphite)
                    } else {
                        NotSentLabel(kind: kind)
                    }
                }
                Spacer(minLength: Space.s)
                Image(systemName: "chevron.right").font(Typo.caption).foregroundStyle(Theme.graphite2)
            }
            .frame(minHeight: 44)
            .padding(.vertical, Space.s)
            .overlay(alignment: .bottom) {
                if !last { Rectangle().fill(Theme.hair).frame(height: 0.5) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens details")
    }

    // MARK: Trend card

    private func trendButton(_ t: Insights.Trend) -> some View {
        Button { sheet = health.state(t.id) } label: { TrendCard(trend: t) }
            .buttonStyle(PressStyle())
            .accessibilityHint("Opens \(t.id.info.name) details")
    }

    // MARK: Tags vs recovery (journal discoveries)

    private var tagsCard: some View {
        let found = journal.discoveries
        let tagged = min(journal.taggedDays, JournalStore.discoveryThreshold)
        return Card(spacing: Space.l) {
            if found.isEmpty {
                Text("Tag your days to see what moves your recovery.")
                    .typo(.headline).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.s) {
                    ForEach(0..<JournalStore.discoveryThreshold, id: \.self) { i in
                        Circle()
                            .fill(i < tagged ? Theme.ink : Theme.hair)
                            .frame(width: 8, height: 8)
                    }
                    Text(journal.progressText ?? "Looking for patterns")
                        .typo(.caption).foregroundStyle(Theme.graphite)
                        .padding(.leading, Space.xs)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(tagged) of \(JournalStore.discoveryThreshold) tagged days. \(journal.progressText ?? "")")
                Button { nav.showJournal = true } label: {
                    Label("Tag today", systemImage: "plus")
                        .typo(.label).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.paper, in: Capsule())
                }
                .buttonStyle(PressStyle())
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(found.enumerated()), id: \.offset) { i, line in
                        Text(line).typo(.body).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Space.m)
                            .overlay(alignment: .bottom) {
                                if i < found.count - 1 { Rectangle().fill(Theme.hair).frame(height: 0.5) }
                            }
                    }
                }
                .padding(.vertical, -Space.m)
                Text("Patterns from \(journal.taggedDays) tagged days, not causes.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            }
        }
    }
}

// MARK: - Trend card (sentence + 14 bars + two averages)

/// Apple-Trends card: metric name and status word, the takeaway sentence, then 14 grey bars
/// with the week-before average (graphite) and the last-7-days average (status colour only
/// when it moved meaningfully in a direction that matters, ink otherwise). Direct labels, no legend.
struct TrendCard: View {
    let trend: Insights.Trend

    private struct Bar: Identifiable { let i: Int; let v: Double; let recent: Bool; var id: Int { i } }

    var body: some View {
        let t = trend
        let tier = TrendCopy.tier(t)
        let lineColor = tier?.fill ?? Theme.ink
        let labelColor = tier?.chipColors.text ?? Theme.ink
        let prev = t.previousValues.count
        let bars = t.previousValues.enumerated().map { Bar(i: $0.offset, v: $0.element, recent: false) }
            + t.recentValues.enumerated().map { Bar(i: prev + $0.offset, v: $0.element, recent: true) }
        let total = bars.count
        let all = bars.map(\.v)
        let lo = min(all.min() ?? 0, 0)
        let top = max(all.max() ?? 1, 0)
        let hi = top + max(top - lo, 0.0001) * 0.22   // headroom for the direct labels

        Card(spacing: Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(t.id.info.name).typo(.label).foregroundStyle(Theme.graphite)
                Spacer(minLength: Space.s)
                if TrendCopy.reading(t) != .steady {
                    if let tier {
                        trendChip(t, tier)
                    } else {
                        Text(TrendCopy.word(t)).typo(.label).foregroundStyle(Theme.ink)
                    }
                }
            }

            (Text(TrendCopy.sentence(t)).foregroundStyle(Theme.ink)
             + Text(TrendCopy.action(t).map { " " + $0 } ?? "").foregroundStyle(Theme.graphite))
                .typo(.headline)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Chart {
                ForEach(bars) { b in dayBar(b) }
                RuleMark(xStart: .value("From", 0), xEnd: .value("To", Double(prev)), y: .value("Week before", t.previous))
                    .foregroundStyle(Theme.graphite)
                    .lineStyle(MRHChart.line)
                    .annotation(position: .top, alignment: .leading, spacing: Space.xs) {
                        Text(TrendCopy.value(t.id, t.previous)).typo(.caption).foregroundStyle(Theme.graphite)
                    }
                RuleMark(xStart: .value("From", Double(prev)), xEnd: .value("To", Double(total)), y: .value("Last 7 days", t.recent))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .annotation(position: .top, alignment: .trailing, spacing: Space.xs) {
                        Text(TrendCopy.value(t.id, t.recent)).typo(.label).foregroundStyle(labelColor)
                    }
            }
            .chartXScale(domain: 0...Double(max(total, 1)))
            .chartYScale(domain: lo...hi)
            .mrhGrid()
            .frame(height: 96)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(t.id.info.name), 14 days")
            .accessibilityValue("Week before averaged \(TrendCopy.value(t.id, t.previous)), last 7 days averaged \(TrendCopy.value(t.id, t.recent))")

            HStack {
                Text("Week before").foregroundStyle(Theme.graphite)
                Spacer()
                Text("Last 7 days").foregroundStyle(labelColor)
            }
            .typo(.caption)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    /// One day's column. Numeric x-axis: `width: .ratio()` collapses to 0 pt there, and
    /// xStart/xEnd + y alone draws a floating horizontal bar, so both axes get explicit edges.
    private func dayBar(_ b: Bar) -> some ChartContent {
        let x0: Double = Double(b.i) + 0.15
        let x1: Double = Double(b.i) + 0.85
        let style: Color = b.recent ? Theme.graphite2 : Theme.graphite2.opacity(0.55)
        let shape = UnevenRoundedRectangle(cornerRadii: .init(topLeading: MRHChart.barRadius,
                                                               topTrailing: MRHChart.barRadius))
        return RectangleMark(xStart: .value("Day", x0), xEnd: .value("Day", x1),
                             yStart: .value("Zero", 0.0), yEnd: .value("Value", b.v))
            .foregroundStyle(style)
            .clipShape(shape)
    }

    /// Status chip carrying the trend word ("Better" / "Watch") so colour never stands alone.
    private func trendChip(_ t: Insights.Trend, _ tier: StatusTier) -> some View {
        HStack(spacing: Space.xs) {
            Circle().fill(tier.fill).frame(width: 6, height: 6)
            Text(TrendCopy.word(t)).typo(.label).foregroundStyle(tier.chipColors.text)
        }
        .padding(.horizontal, Space.s)
        .padding(.vertical, Space.xs)
        .background(tier.chipColors.bg, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }
}
