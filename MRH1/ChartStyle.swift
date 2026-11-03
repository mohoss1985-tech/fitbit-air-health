import SwiftUI
import Charts

// MRH1 chart styling (DESIGN_SPEC §3 "Charts", research/04 "Chart spec"). Owner: Graphics (B).
//
// Usage on any Swift Charts `Chart`:
//     Chart { LineMark(...).interpolationMethod(.monotone).lineStyle(MRHChart.line) }
//         .mrhAxes()                 // full axes: x labels, y labels + dotted hair grid (max 3)
//     Chart { ... }.mrhGrid()        // compact: dotted grid only, no labels
// Use ONE of the two per chart (the innermost axis modifier wins in Swift Charts).
//
// Grained fill (Live HR + Strain-detail HR only):
//     AreaMark(...).foregroundStyle(.grainedArea())   // ink line; pass Theme.ember for Strain
// Bars / gauges: add `.printGrain(amount: 0.03)` to the drawn shape (not to text).

enum MRHChart {
    /// 1.75 pt, round caps and joins.
    static let line = StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
    /// Gridlines: hair 0.5 pt, dotted 1 on / 3 off.
    static let grid = StrokeStyle(lineWidth: 0.5, lineCap: .butt, dash: [1, 3])
    /// Max horizontal gridlines.
    static let gridCount = 3
    /// Bar spacing and top radius.
    static let barGap: CGFloat = 3
    static let barRadius: CGFloat = 2
}

extension View {
    /// MRH1 axis styling for Swift Charts: caption (SF Pro, tabular) labels in graphite,
    /// no ticks, no x grid, horizontal dotted hair grid (max 3), no default blue.
    func mrhAxes(xCount: Int = 4, yCount: Int = MRHChart.gridCount) -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: xCount)) { _ in
                    AxisValueLabel()
                        .font(Typo.caption.monospacedDigit())
                        .foregroundStyle(Theme.graphite)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: yCount)) { _ in
                    AxisGridLine(stroke: MRHChart.grid)
                        .foregroundStyle(Theme.graphite2)
                    AxisValueLabel()
                        .font(Typo.caption.monospacedDigit())
                        .foregroundStyle(Theme.graphite)
                }
            }
            .tint(Theme.ink)
    }

    /// MRH1 gridlines only: horizontal, hair 0.5 pt dotted, max 3; axes and labels hidden.
    /// For compact charts (cards, sparklines). Use instead of `.mrhAxes()`, not with it.
    func mrhGrid(lines: Int = MRHChart.gridCount) -> some View {
        self
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: lines)) { _ in
                    AxisGridLine(stroke: MRHChart.grid)
                        .foregroundStyle(Theme.graphite2)
                }
            }
            .tint(Theme.ink)
    }

    /// Static print grain (amount = OKLab L amplitude, e.g. 0.03 = ±3 %). Per device pixel,
    /// never animated (reseeds daily). Also varies ink density on translucent pixels so fills
    /// look printed. Apply to shapes/fills, not to text.
    func printGrain(amount: Double) -> some View {
        modifier(PrintGrain(amount: amount))
    }
}

private struct PrintGrain: ViewModifier {
    var amount: Double
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        content.colorEffect(ShaderLibrary.mrhGrain(
            .float(Float(amount)),
            .float(Float(displayScale)),
            .float(Float(MRHGrainSeed.today))
        ), isEnabled: amount > 0)
    }
}

enum MRHGrainSeed {
    /// Changes once per day, so grain is static but not identical forever.
    static var today: Int {
        (Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 1) % 9973
    }
}

/// Grained vertical area fill: ink 12 % (default) or series colour 24 % at the top → 0 % at the
/// baseline, OKLab, ±3 % L printed grain (ref 28). Only Live HR + Strain detail (§1).
/// As a view it fills its frame (put it under a custom `Path` via `.mask`, or in a
/// `chartBackground`); for Swift Charts marks use `.foregroundStyle(.grainedArea(color))`.
struct GrainedAreaFill: View {
    var color: Color = Theme.ink
    /// Top alpha. nil = 0.12 for ink (default single-series charts), 0.24 for a series colour.
    var top: Double? = nil
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Shader.grainedArea(color, top: top, scale: displayScale))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension ShapeStyle where Self == Shader {
    /// ShapeStyle version of `GrainedAreaFill` (e.g. `AreaMark(...).foregroundStyle(.grainedArea())   // ink line; pass Theme.ember for Strain`).
    /// The ramp spans the bounds of the filled shape. `scale` should be the display scale (3 on
    /// current iPhones) so the grain lands on device pixels.
    static func grainedArea(_ color: Color = Theme.ink, top: Double? = nil, scale: CGFloat = 3) -> Shader {
        let top = top ?? (color == Theme.ink ? 0.12 : 0.24)
        return ShaderLibrary.mrhGrainedArea(
            .boundingRect,
            .color(color),
            .float(Float(top)),
            .float(0.03),
            .float(Float(scale)),
            .float(Float(MRHGrainSeed.today))
        )
    }
}

/// Current-value point for Swift Charts: 6 pt ember dot + 2 pt card ring, one ripple per
/// `pulse` increment (Live only). `LivePointMark(x: .value("Time", t), y: .value("BPM", v), pulse: live.pulse)`
struct LivePointMark<X: Plottable, Y: Plottable>: ChartContent {
    var x: PlottableValue<X>
    var y: PlottableValue<Y>
    var pulse: Int = 0
    var color: Color = Theme.ember

    var body: some ChartContent {
        PointMark(x: x, y: y)
            .symbol {
                LivePulse(pulse: pulse, color: color)
            }
    }
}
