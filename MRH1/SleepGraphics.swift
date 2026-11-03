import SwiftUI

// Sleep graphics (owner: I). Stage colours come from Theme: deep = ink-iris, light = peach-graphite,
// REM = iris, awake = danger 60 %. No blue.

extension SleepStage {
    /// Short name for direct labels (the full `label` says "REM (dreaming)").
    var shortLabel: String { self == .rem ? "REM" : label }

    /// Top-to-bottom order in the hypnogram: awake on top, deep at the bottom.
    var hypnoRow: Int {
        switch self {
        case .awake: return 0
        case .rem: return 1
        case .light: return 2
        case .deep: return 3
        }
    }

    /// Left-to-right order in the proportional bar: deepest first, awake last.
    static var barOrder: [SleepStage] { [.deep, .light, .rem, .awake] }
}

/// Proportional bar of sleep stages for the night (Today "Last night", Sleep detail).
/// Height comes from the caller; segments are separated by 2 pt paper gaps, 2 pt radius.
struct StageBar: View {
    let session: SleepSession

    private var total: Double { max(session.segments.reduce(0) { $0 + $1.minutes }, 1) }

    var body: some View {
        GeometryReader { geo in
            let stages = SleepStage.barOrder.filter { session.minutes($0) > 0 }
            let gaps = CGFloat(max(stages.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(stages, id: \.self) { stage in
                    RoundedRectangle(cornerRadius: Radius.bar, style: .continuous)
                        .fill(stage.color)
                        .frame(width: max((geo.size.width - gaps) * session.minutes(stage) / total, 2))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stages")
        .accessibilityValue(SleepStage.barOrder
            .filter { session.minutes($0) > 0 }
            .map { "\($0.shortLabel) \(MetricID.sleepTotal.format(session.minutes($0)))" }
            .joined(separator: ", "))
    }
}

/// Stage-by-stage timeline of the night. Rows are direct-labelled on the left (no legend),
/// stage blocks are joined by hairline risers so the night reads as one stepped line.
struct Hypnogram: View {
    let session: SleepSession
    /// Leading label column. Set to false for a bare graphic.
    var showsLabels: Bool = true

    private let labelW: CGFloat = 44
    private let axisH: CGFloat = 20

    var body: some View {
        VStack(spacing: Space.xs) {
            GeometryReader { geo in
                let plotX: CGFloat = showsLabels ? labelW : 0
                let plotW = max(geo.size.width - plotX, 1)
                let rowH = geo.size.height / 4
                ZStack(alignment: .topLeading) {
                    if showsLabels {
                        ForEach(SleepStage.allCases, id: \.self) { st in
                            Text(st.shortLabel)
                                .typo(.micro)
                                .foregroundStyle(Theme.graphite)
                                .frame(width: labelW - Space.s, height: rowH, alignment: .leading)
                                .offset(y: rowH * CGFloat(st.hypnoRow))
                        }
                    }
                    Canvas { ctx, size in
                        draw(ctx: ctx, size: size, rowH: rowH)
                    }
                    .frame(width: plotW, height: geo.size.height)
                    .offset(x: plotX)
                }
            }
            if showsLabels { timeAxis }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stages through the night")
        .accessibilityValue(accessibilitySummary)
    }

    private func draw(ctx: GraphicsContext, size: CGSize, rowH: CGFloat) {
        let total = max(session.end.timeIntervalSince(session.start), 1)
        // Row guides: dotted hair, like the chart grid.
        for r in 0..<4 {
            let y = rowH * CGFloat(r) + rowH / 2
            var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(Theme.hair), style: StrokeStyle(lineWidth: 0.5, dash: [1, 3]))
        }
        let segs = session.segments.sorted { $0.start < $1.start }
        let barH = min(rowH * 0.62, 14)
        func x(_ d: Date) -> CGFloat { size.width * d.timeIntervalSince(session.start) / total }
        func midY(_ s: SleepStage) -> CGFloat { rowH * CGFloat(s.hypnoRow) + rowH / 2 }
        // Risers between consecutive blocks.
        for (a, b) in zip(segs, segs.dropFirst()) where b.start.timeIntervalSince(a.end) < 120 && a.stage != b.stage {
            let rx = x(b.start)
            var p = Path()
            p.move(to: CGPoint(x: rx, y: midY(a.stage)))
            p.addLine(to: CGPoint(x: rx, y: midY(b.stage)))
            ctx.stroke(p, with: .color(Theme.graphite2), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
        }
        for seg in segs {
            let x0 = x(seg.start)
            let w = max(x(seg.end) - x0, 1.5)
            let r = CGRect(x: x0, y: midY(seg.stage) - barH / 2, width: w, height: barH)
            ctx.fill(Path(roundedRect: r, cornerRadius: min(Radius.bar, w / 2)), with: .color(seg.stage.color))
        }
    }

    private var timeAxis: some View {
        HStack(spacing: 0) {
            if showsLabels { Spacer().frame(width: labelW) }
            Text(session.start.formatted(date: .omitted, time: .shortened))
            Spacer(minLength: Space.s)
            Text(session.end.formatted(date: .omitted, time: .shortened))
        }
        .typo(.caption)
        .foregroundStyle(Theme.graphite)
        .frame(height: axisH)
    }

    private var accessibilitySummary: String {
        let parts = SleepStage.barOrder.map { "\($0.shortLabel) \(MetricID.sleepTotal.format(session.minutes($0)))" }
        return "From \(session.start.formatted(date: .omitted, time: .shortened)) to \(session.end.formatted(date: .omitted, time: .shortened)). " + parts.joined(separator: ", ")
    }
}

/// Direct-labelled stage totals under the hypnogram: swatch · name · minutes · share.
struct StageTotals: View {
    let session: SleepSession

    var body: some View {
        let asleep = max(session.segments.reduce(0) { $0 + $1.minutes }, 1)
        VStack(spacing: Space.s) {
            ForEach(SleepStage.barOrder, id: \.self) { st in
                let m = session.minutes(st)
                HStack(spacing: Space.s) {
                    RoundedRectangle(cornerRadius: Radius.bar).fill(st.color).frame(width: 10, height: 10)
                    Text(st.shortLabel).typo(.body).foregroundStyle(Theme.ink)
                    Spacer(minLength: Space.s)
                    Text(m > 0 ? MetricID.sleepTotal.format(m) : "—").typo(.body).foregroundStyle(Theme.ink)
                    Text("\(Int((m / asleep * 100).rounded())) %")
                        .typo(.caption).foregroundStyle(Theme.graphite)
                        .frame(minWidth: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
