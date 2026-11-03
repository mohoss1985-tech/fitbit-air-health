import SwiftUI
import Charts

// Live tab heart-rate chart (DESIGN_SPEC §3 charts, §4 Live; research/04 "Chart spec").
// Live / 1H / 24H: monotone 1.75 pt ink line over a grained ember fill, gaps kept as gaps,
// ember current point with one ripple per new sample. 24H shades sleep and workouts.
// 7D / 30D: one min–max capsule per day with the daily average line, inside the band of your
// usual daily average. Every range is scrubbable (value bubble + selection haptic).

/// One drawable point on the line. `segment` breaks the line where data is missing.
struct LiveChartPoint: Identifiable, Hashable {
    let date: Date
    let bpm: Double
    let segment: Int
    var id: Date { date }
}

/// A shaded time window on the 24H chart.
struct LiveChartShade: Identifiable, Hashable {
    enum Kind: String { case sleep = "Sleep", workout = "Workout" }
    let kind: Kind
    let start: Date
    let end: Date
    var id: String { kind.rawValue + "\(start.timeIntervalSince1970)" }
}

/// Everything the chart needs, computed once from `RangeStats` so the view stays dumb.
struct LiveChartModel {
    let range: LiveRange
    let from: Date
    let to: Date
    let line: [LiveChartPoint]          // Live, 1H, 24H
    let days: [HRBucket]                // 7D, 30D
    let shades: [LiveChartShade]        // 24H
    let usual: ClosedRange<Double>?     // 7D / 30D band (your usual daily average)
    let yDomain: ClosedRange<Double>

    var isDaily: Bool { range == .d7 || range == .d30 }
    var hasData: Bool { isDaily ? !days.isEmpty : !line.isEmpty }
    var last: LiveChartPoint? { line.last }

    init(stats s: RangeStats, shades: [LiveChartShade], usual: ClosedRange<Double>?) {
        range = s.range
        from = s.from
        to = s.to
        self.usual = s.range == .d7 || s.range == .d30 ? usual : nil

        // Raw points for Live, bucket averages for 1H / 24H.
        let raw: [(Date, Double)]
        switch s.range {
        case .live: raw = s.points.map { ($0.date, $0.bpm) }
        case .h1, .h24: raw = s.buckets.map { ($0.start.addingTimeInterval(s.range.bucketSeconds / 2), $0.avg) }
        case .d7, .d30: raw = []
        }
        // A gap longer than this breaks the line (never interpolate across missing data).
        let maxGap: TimeInterval
        switch s.range {
        case .live: maxGap = 6 * 60
        case .h1: maxGap = 4 * 60
        default: maxGap = 2.5 * 3600
        }
        var seg = 0
        var out: [LiveChartPoint] = []
        for (i, p) in raw.enumerated() {
            if i > 0, p.0.timeIntervalSince(raw[i - 1].0) > maxGap { seg += 1 }
            out.append(LiveChartPoint(date: p.0, bpm: p.1, segment: seg))
        }
        line = out
        days = s.range == .d7 || s.range == .d30 ? s.buckets : []
        self.shades = s.range == .h24
            ? shades.compactMap { sh in
                let a = max(sh.start, s.from), b = min(sh.end, s.to)
                return a < b ? LiveChartShade(kind: sh.kind, start: a, end: b) : nil
            }
            : []

        // Padded y domain on familiar 10s; never starts at 0 (lines, not bars).
        var lo = Double.greatestFiniteMagnitude, hi = -Double.greatestFiniteMagnitude
        for p in out { lo = Swift.min(lo, p.bpm); hi = Swift.max(hi, p.bpm) }
        for d in days { lo = Swift.min(lo, d.min); hi = Swift.max(hi, d.max) }
        if let u = self.usual { lo = Swift.min(lo, u.lowerBound); hi = Swift.max(hi, u.upperBound) }
        if lo > hi { lo = 50; hi = 90 }
        let pad = Swift.max((hi - lo) * 0.12, 4)
        let a = ((lo - pad) / 10).rounded(.down) * 10
        let b = ((hi + pad) / 10).rounded(.up) * 10
        yDomain = Swift.max(a, 0)...Swift.max(b, a + 20)
    }
}

struct LiveChart: View {
    let model: LiveChartModel
    var pulse: Int = 0

    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: Date?

    var body: some View {
        chart
            .frame(height: 200)
            .accessibilityChartDescriptor(LiveChartDescriptor(model: model))
            .sensoryFeedback(.selection, trigger: selectedKey)
    }

    // MARK: Chart

    private var chart: some View {
        Chart {
            if model.isDaily { dailyMarks } else { lineMarks }
            selectionMarks
        }
        .chartYScale(domain: model.yDomain)
        .chartXScale(domain: xDomain)
        .chartXSelection(value: $selection)
        .chartLegend(.hidden)
        .mrhAxes(xCount: model.range == .d30 ? 4 : 3, yCount: 3)
        .chartXAxis { xAxis }
    }

    private var xDomain: ClosedRange<Date> {
        if model.isDaily {
            // Daily capsules sit at noon; pad half a day either side so the ends aren't clipped.
            let cal = Calendar.current
            let a = cal.startOfDay(for: model.from)
            let b = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: model.to)) ?? model.to
            return a...b
        }
        return model.from...model.to
    }

    @ChartContentBuilder
    private var lineMarks: some ChartContent {
        ForEach(model.shades) { sh in
            RectangleMark(xStart: .value("Start", sh.start), xEnd: .value("End", sh.end))
                .foregroundStyle(sh.kind == .sleep ? Theme.iris.opacity(0.10) : Theme.ember.opacity(0.08))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text(sh.kind.rawValue)
                        .typo(.micro)
                        .foregroundStyle(Theme.graphite)
                }
        }
        ForEach(model.line) { p in
            AreaMark(x: .value("Time", p.date),
                     yStart: .value("Base", model.yDomain.lowerBound),
                     yEnd: .value("BPM", p.bpm),
                     series: .value("Segment", "a\(p.segment)"))
                .interpolationMethod(.monotone)
                .foregroundStyle(.grainedArea(Theme.ember, scale: displayScale))
        }
        ForEach(model.line) { p in
            LineMark(x: .value("Time", p.date), y: .value("BPM", p.bpm),
                     series: .value("Segment", "l\(p.segment)"))
                .interpolationMethod(.monotone)
                .lineStyle(MRHChart.line)
                .foregroundStyle(Theme.ink)
        }
        // A lone point between two gaps has no line to draw; give it a small ink dot.
        ForEach(isolatedPoints) { p in
            PointMark(x: .value("Time", p.date), y: .value("BPM", p.bpm))
                .symbolSize(10)
                .foregroundStyle(Theme.ink)
        }
        if let last = model.last {
            LivePointMark(x: .value("Time", last.date), y: .value("BPM", last.bpm),
                          pulse: model.range == .live || model.range == .h1 ? pulse : 0)
        }
    }

    @ChartContentBuilder
    private var dailyMarks: some ChartContent {
        if let u = model.usual {
            RectangleMark(xStart: .value("Start", xDomain.lowerBound), xEnd: .value("End", xDomain.upperBound),
                          yStart: .value("Usual low", u.lowerBound), yEnd: .value("Usual high", u.upperBound))
                .foregroundStyle(Theme.bandFill)
        }
        ForEach(model.days) { d in
            RuleMark(x: .value("Day", noon(d.start)),
                     yStart: .value("Lowest", d.min), yEnd: .value("Highest", d.max))
                .lineStyle(StrokeStyle(lineWidth: model.range == .d7 ? 8 : 4, lineCap: .round))
                .foregroundStyle(Theme.graphite2.opacity(0.55))
        }
        ForEach(model.days) { d in
            LineMark(x: .value("Day", noon(d.start)), y: .value("Average", d.avg))
                .interpolationMethod(.monotone)
                .lineStyle(MRHChart.line)
                .foregroundStyle(Theme.ink)
        }
        if let last = model.days.last {
            LivePointMark(x: .value("Day", noon(last.start)), y: .value("Average", last.avg), pulse: 0)
        }
    }

    @ChartContentBuilder
    private var selectionMarks: some ChartContent {
        if let s = selected {
            RuleMark(x: .value("Selected", s.date))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .annotation(position: .top, spacing: 4,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    bubble(s)
                }
            PointMark(x: .value("Selected", s.date), y: .value("BPM", s.value))
                .symbolSize(36)
                .foregroundStyle(Theme.ink)
        }
    }

    private var xAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: model.range == .d30 ? 4 : 3)) { v in
            AxisValueLabel {
                if let d = v.as(Date.self) {
                    Text(xLabel(d))
                        .typo(.caption)
                        .foregroundStyle(Theme.graphite)
                }
            }
        }
    }

    // MARK: Selection

    private struct Selected: Equatable {
        let date: Date
        let value: Double
        let text: String
        let sub: String
    }

    private var selected: Selected? {
        guard let t = selection else { return nil }
        if model.isDaily {
            guard let d = model.days.min(by: { abs(noon($0.start).timeIntervalSince(t)) < abs(noon($1.start).timeIntervalSince(t)) })
            else { return nil }
            return Selected(date: noon(d.start), value: d.avg,
                            text: "\(Int(d.avg.rounded())) bpm average",
                            sub: d.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                + ", \(Int(d.min.rounded()))–\(Int(d.max.rounded()))")
        }
        guard let p = model.line.min(by: { abs($0.date.timeIntervalSince(t)) < abs($1.date.timeIntervalSince(t)) })
        else { return nil }
        // Don't snap across a gap: only select if the finger is near a real point.
        let tolerance: TimeInterval = model.range == .h24 ? 3600 : (model.range == .h1 ? 180 : 300)
        guard abs(p.date.timeIntervalSince(t)) <= tolerance else { return nil }
        let time = model.range == .h24 && model.range.bucketSeconds >= 3600
            ? "Around " + p.date.formatted(date: .omitted, time: .shortened)
            : p.date.formatted(date: .omitted, time: .shortened)
        return Selected(date: p.date, value: p.bpm, text: "\(Int(p.bpm.rounded())) bpm", sub: time)
    }

    private var selectedKey: Date? { selected?.date }

    private func bubble(_ s: Selected) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s.text).typo(.label).foregroundStyle(Theme.ink)
            Text(s.sub).typo(.micro).foregroundStyle(Theme.graphite)
        }
        .padding(.horizontal, Space.s)
        .padding(.vertical, Space.xs)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).stroke(Theme.hair, lineWidth: 0.5))
        .fixedSize()
    }

    // MARK: Helpers

    private var isolatedPoints: [LiveChartPoint] {
        let counts = Dictionary(grouping: model.line, by: \.segment).mapValues(\.count)
        return model.line.filter { counts[$0.segment] == 1 && $0.id != model.last?.id }
    }

    private func noon(_ d: Date) -> Date { Calendar.current.startOfDay(for: d).addingTimeInterval(12 * 3600) }

    private func xLabel(_ d: Date) -> String {
        switch model.range {
        case .live, .h1, .h24: return d.formatted(.dateTime.hour().minute())
        case .d7: return d.formatted(.dateTime.weekday(.abbreviated))
        case .d30: return d.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

// MARK: - VoiceOver (Audio Graphs)

struct LiveChartDescriptor: AXChartDescriptorRepresentable {
    let model: LiveChartModel

    func makeChartDescriptor() -> AXChartDescriptor {
        let values: [(Date, Double)] = model.isDaily
            ? model.days.map { ($0.start, $0.avg) }
            : model.line.map { ($0.date, $0.bpm) }
        let lo = values.map(\.1).min() ?? model.yDomain.lowerBound
        let hi = values.map(\.1).max() ?? model.yDomain.upperBound
        let x = AXNumericDataAxisDescriptor(
            title: "Time",
            range: model.from.timeIntervalSince1970...Swift.max(model.to.timeIntervalSince1970, model.from.timeIntervalSince1970 + 1),
            gridlinePositions: []
        ) { Date(timeIntervalSince1970: $0).formatted(date: model.isDaily ? .abbreviated : .omitted, time: model.isDaily ? .omitted : .shortened) }
        let y = AXNumericDataAxisDescriptor(
            title: model.isDaily ? "Average heart rate" : "Heart rate",
            range: lo...Swift.max(hi, lo + 1),
            gridlinePositions: []
        ) { "\(Int($0.rounded())) beats per minute" }
        let series = AXDataSeriesDescriptor(
            name: "Heart rate",
            isContinuous: !model.isDaily,
            dataPoints: values.map { AXDataPoint(x: $0.0.timeIntervalSince1970, y: $0.1) }
        )
        let summary: String
        if values.isEmpty {
            summary = "No heart rate in this range yet."
        } else {
            summary = "Heart rate from \(Int(lo.rounded())) to \(Int(hi.rounded())) beats per minute."
        }
        return AXChartDescriptor(title: "Heart rate, \(model.range.rawValue)", summary: summary,
                                 xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }
}
