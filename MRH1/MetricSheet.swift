import SwiftUI
import Charts

/// The "lab result" sheet: value and status, your range on a dot-matrix strip, what it means,
/// and a Week/Month trend against your personal band. `MetricSheet(state:)` is presented by
/// MetricRow, Body, Trends, the health monitor and the score details.
struct MetricSheet: View {
    let state: MetricState

    @State private var range: Int = 7
    @State private var selected: Date?

    private var info: MetricInfo { state.id.info }
    private var unit: String { info.unit }

    private var points: [DayValue] {
        guard let last = state.series.last?.date else { return [] }
        let from = Calendar.current.date(byAdding: .day, value: -(range - 1), to: Calendar.current.startOfDay(for: last)) ?? last
        return state.series.filter { $0.date >= from }
    }

    private var picked: DayValue? {
        guard let selected else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                if state.hasData {
                    VStack(alignment: .leading, spacing: Space.s) {
                        RangeStrip(state: state)
                        Text(rangeCaption).typo(.caption).foregroundStyle(Theme.graphite)
                    }
                }
                rangeTiles
                Text(info.what)
                    .typo(.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                directionTiles
                trendSection
                SheetDisclaimer()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.section)
            .padding(.bottom, Space.xl)
        }
        .background(Theme.card)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.card)
        .presentationCornerRadius(Radius.card)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(info.name).typo(.title).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(info.sub).typo(.caption).foregroundStyle(Theme.graphite)
            }
            Spacer(minLength: Space.s)
            VStack(alignment: .trailing, spacing: Space.s) {
                if state.hasData {
                    ValueText(value: state.valueText, unit: unit, size: .metric)
                    if state.missing == .waiting {
                        NotSentLabel(kind: .waiting, short: true)
                    } else {
                        StatusChip(state: state)
                    }
                } else {
                    ValueText(value: "—", size: .metric)
                    NotSentLabel(kind: missingKind, short: true)
                }
            }
        }
    }

    private var rangeCaption: String {
        var parts: [String] = [state.directionText + "."]
        if let early = state.earlyReadText { parts.append(early) }
        if state.missing == .waiting, let d = state.latest?.date {
            parts.append("Last reading \(d.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))).")
        }
        return parts.joined(separator: " ")
    }

    // MARK: Tiles

    private var rangeTiles: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Space.s) { yourRangeTile; typicalTile }
            VStack(spacing: Space.s) { yourRangeTile; typicalTile }
        }
    }

    private var yourRangeTile: some View {
        tile(label: "Your range", text: state.yourRangeText, emphasis: true)
    }

    private var typicalTile: some View {
        tile(label: "Typical adult", text: info.typicalText, emphasis: false)
    }

    private var directionTiles: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Space.s) { higherTile; lowerTile }
            VStack(spacing: Space.s) { higherTile; lowerTile }
        }
    }

    private var higherTile: some View {
        tile(label: "If higher", text: info.ifHigh, emphasis: false, symbol: "arrow.up")
    }

    private var lowerTile: some View {
        tile(label: "If lower", text: info.ifLow, emphasis: false, symbol: "arrow.down")
    }

    private func tile(label: String, text: String, emphasis: Bool, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 11, weight: .regular)).foregroundStyle(Theme.graphite)
                }
                Text(label).typo(.label).foregroundStyle(Theme.graphite)
            }
            Text(text)
                .typo(emphasis ? .headline : .body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Trend

    @ViewBuilder private var trendSection: some View {
        if !state.hasData {
            missingBlock(kind: missingKind, text: missingKind == .notSent
                ? "Google Health doesn’t write this to Apple Health. It appears here automatically if that changes."
                : "Google Health hasn’t shared this metric with Apple Health yet. It appears here automatically once it does.")
        } else if state.series.count < 2 {
            missingBlock(kind: nil, text: "The trend chart appears after a few days of data.")
        } else {
            chartBlock
        }
    }

    private func missingBlock(kind: NotSentKind?, text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Trend").typo(.headline).foregroundStyle(Theme.ink)
            if let kind { NotSentLabel(kind: kind) }
            Text(text).typo(.body).foregroundStyle(Theme.graphite).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trend").typo(.headline).foregroundStyle(Theme.ink)
                    Text(takeaway).typo(.caption).foregroundStyle(Theme.graphite)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: Space.s)
                PillPicker(selection: $range, options: [7, 31]) { $0 == 7 ? "Week" : "Month" }
                    .frame(width: 148)
            }

            chart
                .frame(height: 188)
                .transition(.opacity)
                .id(range)
                .animation(Motion.crossfade, value: range)

            HStack(spacing: Space.s) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.bandFill).frame(width: 16, height: 8)
                Text(state.baseline != nil ? "Shaded band is your normal range." : "Shaded band is the typical adult range.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            }
            Text("Press and drag on the chart to read each day.")
                .typo(.caption).foregroundStyle(Theme.graphite)
        }
        .padding(Space.l)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
    }

    private var takeaway: String {
        let vals = points.map(\.value)
        guard !vals.isEmpty else { return "" }
        let avg = vals.reduce(0, +) / Double(vals.count)
        let unitPart = unit.isEmpty ? "" : "\u{00A0}" + unit
        let outside = points.filter { isOutside($0.value) }.count
        let span = range == 7 ? "this week" : "this month"
        let lead = "Average \(state.id.format(avg))\(unitPart) \(span)"
        return outside == 0 ? lead + ", all inside the band." : lead + ", \(outside) outside the band."
    }

    private var yDomain: ClosedRange<Double> {
        var vals = points.map(\.value)
        if let b = state.band { vals += [b.lowerBound, b.upperBound] }
        let lo = vals.min() ?? 0, hi = vals.max() ?? 1
        let pad = max((hi - lo) * 0.15, abs(hi) * 0.02, 0.1)
        return (lo - pad)...(hi + pad)
    }

    /// Consecutive-day runs, so a missing day stays a gap in the line.
    private var segments: [(Int, [DayValue])] {
        var out: [[DayValue]] = []
        for p in points {
            if let last = out.last?.last, p.date.timeIntervalSince(last.date) < 36 * 3600 {
                out[out.count - 1].append(p)
            } else {
                out.append([p])
            }
        }
        return Array(out.enumerated())
    }

    private var chart: some View {
        let domain = yDomain
        let first = points.first?.date ?? .now
        let last = points.last?.date ?? .now
        return Chart {
            if let band = state.band {
                RectangleMark(
                    xStart: .value("Start", Calendar.current.date(byAdding: .hour, value: -12, to: first) ?? first),
                    xEnd: .value("End", Calendar.current.date(byAdding: .hour, value: 12, to: last) ?? last),
                    yStart: .value("Low", max(band.lowerBound, domain.lowerBound)),
                    yEnd: .value("High", min(band.upperBound, domain.upperBound))
                )
                .foregroundStyle(Theme.bandFill)
            }
            ForEach(segments, id: \.0) { seg in
                ForEach(seg.1) { p in
                    LineMark(x: .value("Day", p.date), y: .value("Value", p.value), series: .value("Run", seg.0))
                        .interpolationMethod(.monotone)
                        .lineStyle(MRHChart.line)
                        .foregroundStyle(Theme.ink)
                }
            }
            ForEach(points) { p in
                let isPicked = picked?.date == p.date
                PointMark(x: .value("Day", p.date), y: .value("Value", p.value))
                    .symbol {
                        Circle()
                            .fill(pointColor(p.value))
                            .overlay(Circle().strokeBorder(Theme.paper, lineWidth: 2))
                            .frame(width: isPicked ? 12 : (range == 7 ? 10 : 8), height: isPicked ? 12 : (range == 7 ? 10 : 8))
                    }
                    .accessibilityLabel(p.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .accessibilityValue("\(state.id.format(p.value)) \(unit), \(pointWord(p.value))")
            }
            if let picked {
                RuleMark(x: .value("Day", picked.date))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.ink)
                    .annotation(position: .top, spacing: Space.xs,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        bubble(for: picked)
                    }
            }
        }
        .chartXSelection(value: $selected)
        .chartYScale(domain: domain)
        .chartXScale(domain: (Calendar.current.date(byAdding: .hour, value: -12, to: first) ?? first)...(Calendar.current.date(byAdding: .hour, value: 12, to: last) ?? last))
        // Inner axis modifier wins: day labels here, then B's y grid + labels.
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 7)) { _ in
                AxisValueLabel(format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated), centered: false)
                    .font(Typo.caption.monospacedDigit())
                    .foregroundStyle(Theme.graphite)
            }
        }
        // Sleep metrics are stored in minutes; label the axis in hours ("6 h"), not "400".
        .chartYAxis {
            if isDuration {
                AxisMarks(position: .trailing, values: hourTicks(domain)) { v in
                    AxisGridLine(stroke: MRHChart.grid).foregroundStyle(Theme.graphite2)
                    AxisValueLabel {
                        if let m = v.as(Double.self) { Text(hourLabel(m)) }
                    }
                    .font(Typo.caption.monospacedDigit())
                    .foregroundStyle(Theme.graphite)
                }
            } else {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: MRHChart.grid).foregroundStyle(Theme.graphite2)
                    AxisValueLabel().font(Typo.caption.monospacedDigit()).foregroundStyle(Theme.graphite)
                }
            }
        }
        .mrhAxes(xCount: range == 7 ? 7 : 4)
        .sensoryFeedback(.selection, trigger: picked?.date)
        .accessibilityLabel("\(info.name) trend")
    }

    private var isDuration: Bool {
        switch state.id { case .sleepTotal, .deepSleep, .remSleep, .awake: return true; default: return false }
    }

    /// Whole-hour ticks (or half hours / 15 min for short spans), at most 4.
    private func hourTicks(_ d: ClosedRange<Double>) -> [Double] {
        let span = d.upperBound - d.lowerBound
        let step: Double = span > 360 ? 120 : span > 150 ? 60 : span > 60 ? 30 : 15
        var t = (d.lowerBound / step).rounded(.up) * step
        var out: [Double] = []
        while t <= d.upperBound { out.append(t); t += step }
        return out
    }

    private func hourLabel(_ m: Double) -> String {
        let mins = Int(m.rounded())
        if mins % 60 == 0 { return "\(mins / 60) h" }
        return mins < 60 ? "\(mins) min" : "\(mins / 60) h \(String(format: "%02d", mins % 60))"
    }

    private func bubble(for p: DayValue) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .typo(.caption).foregroundStyle(Theme.graphite)
            ValueText(value: state.id.format(p.value), unit: unit, size: .headline)
            Text(pointWord(p.value)).typo(.micro).foregroundStyle(Theme.graphite)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(Theme.hair, lineWidth: 0.5))
    }

    // MARK: Point status (direction-aware, never blue)

    private func isOutside(_ v: Double) -> Bool {
        guard let b = state.band else { return false }
        return v > b.upperBound || v < b.lowerBound
    }

    private func isConcern(_ v: Double) -> Bool {
        guard let b = state.band, isOutside(v) else { return false }
        guard let higherIsBetter = Insights.direction(state.id) else { return true }
        return (v > b.upperBound) != higherIsBetter
    }

    private func pointColor(_ v: Double) -> Color {
        guard state.band != nil else { return Theme.ink }
        guard isConcern(v), let b = state.band else { return Theme.good }
        let sd = state.baseline?.sd ?? max((b.upperBound - b.lowerBound) / 2, 0.0001)
        let dist = v > b.upperBound ? (v - b.upperBound) / sd : (b.lowerBound - v) / sd
        return dist > 1 ? Theme.danger : Theme.limit
    }

    private func pointWord(_ v: Double) -> String {
        guard let b = state.band else { return "No range yet" }
        if v > b.upperBound { return "Above your range" }
        if v < b.lowerBound { return "Below your range" }
        return "In your range"
    }

    private var missingKind: NotSentKind {
        switch state.missing {
        case .notSent: return .notSent
        case .waiting: return .waiting
        default: return state.id.isNotSentByGoogle ? .notSent : .noReading
        }
    }
}
