import SwiftUI
import Charts

// Shader-backed chart pieces (research/06 + DESIGN_SPEC §3 "Charts").
//   GlowLine   — crisp SDF line + grained fill (+ 6 pt glow in dark mode only)
//   LivePulse  — current point: 6 pt ember dot, 2 pt card ring, ONE ripple per `pulse` change
//   Hairline   — 1-device-pixel line snapped to the pixel grid
//   .mrhGlowUnderlay(_:) — draws a GlowLine exactly inside a Swift Charts plot area

// MARK: - Glow line

/// Line + grained area fill drawn by `mrhChartLine`. Values are evenly spaced in x;
/// `nil` makes a gap ("Not sent", sync holes stay holes).
/// Grained fill is allowed only on the Live HR and Strain-detail HR charts (DESIGN_SPEC §1):
/// pass `fill: false` everywhere else.
struct GlowLine: View {
    var values: [Double?]
    var domain: ClosedRange<Double>
    var color: Color = Theme.ink
    /// Points. 0 = one device-pixel hairline.
    var lineWidth: CGFloat = 1.75
    var fill: Bool = false
    /// Keeps the stroke from clipping at the top / bottom edge (fraction of height).
    var verticalInset: Double = 0.06
    /// Upper bound on points sent to the GPU (bucket-averaged above this).
    var maxPoints: Int = 240

    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.self) private var env

    var body: some View {
        let ys = normalised()
        let width: CGFloat = lineWidth <= 0 ? 1 / displayScale : lineWidth
        let r = color.resolve(in: env)
        let lab = OKLab(srgbR: r.red, g: r.green, b: r.blue)
        Rectangle()
            .colorEffect(ShaderLibrary.mrhChartLine(
                .boundingRect,
                .floatArray(ys),
                .float(Float(width)),
                lab.arg,
                .float(fill ? (color == Theme.ink ? 0.12 : 0.24) : 0),
                .float(colorScheme == .dark ? 0.22 : 0),   // print doesn't glow
                .float(0.03),
                .float(Float(displayScale))
            ))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func normalised() -> [Float] {
        let src = GlowLine.downsample(values, to: maxPoints)
        let span = max(domain.upperBound - domain.lowerBound, .ulpOfOne)
        let ys: [Float] = src.map { v in
            guard let v else { return -1 }
            let t = min(max((v - domain.lowerBound) / span, 0), 1)
            return Float(verticalInset + t * (1 - 2 * verticalInset))
        }
        return ys.count >= 2 ? ys : [-1, -1]
    }

    /// Bucket mean that keeps gaps: a bucket with no values stays nil.
    static func downsample(_ values: [Double?], to limit: Int) -> [Double?] {
        guard limit >= 2, values.count > limit else { return values }
        let bucket = Double(values.count) / Double(limit)
        return (0..<limit).map { i in
            let lo = Int((Double(i) * bucket).rounded(.down))
            let hi = min(Int((Double(i + 1) * bucket).rounded(.down)), values.count)
            let slice = values[lo..<max(hi, lo + 1)].compactMap { $0 }
            return slice.isEmpty ? nil : slice.reduce(0, +) / Double(slice.count)
        }
    }
}

// MARK: - Live point

/// Current-value point: 6 pt dot with a 2 pt card ring. Each change of `pulse` fires ONE ripple
/// (scale 1 → 2.4, opacity 0.35 → 0, 1.1 s ease-out). It does not loop. Static under Reduce Motion.
/// Dark mode adds a soft 22 % glow.
struct LivePulse: View {
    var pulse: Int = 0
    var color: Color = Theme.ember
    var diameter: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var rippleAt = Date.distantPast
    @State private var running = false

    private static let duration: TimeInterval = 1.1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !running)) { context in
            let k = min(max(context.date.timeIntervalSince(rippleAt) / Self.duration, 0), 1)
            let e = 1 - pow(1 - k, 3)                       // ease-out
            ZStack {
                if k < 1 {
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: diameter, height: diameter)
                        .scaleEffect(1 + 1.4 * e)
                        .opacity(0.35 * (1 - e))
                }
                Circle()
                    .fill(color)
                    .frame(width: diameter, height: diameter)
                    .padding(2)
                    .background(Circle().fill(Theme.card))
                    .shadow(color: colorScheme == .dark ? color.opacity(0.22) : .clear, radius: 6)
            }
            .frame(width: diameter * 2.4 + 4, height: diameter * 2.4 + 4)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: pulse) { _, _ in
            if !reduceMotion { rippleAt = Date(); running = true }
        }
        .task(id: rippleAt) {
            try? await Task.sleep(for: .seconds(Self.duration + 0.05))
            running = false
        }
    }
}

// MARK: - Crisp line helpers

enum PixelSnap {
    /// Centre of a line of `lineWidth` points aligned to the device-pixel grid.
    static func snap(_ v: CGFloat, lineWidth: CGFloat, scale: CGFloat) -> CGFloat {
        let px = (lineWidth * scale).rounded()
        let base = (v * scale).rounded(.down)
        let offset: CGFloat = Int(px) % 2 == 1 ? 0.5 : 0
        return (base + offset) / scale
    }
}

/// A one-device-pixel line snapped to the pixel grid (dividers, baselines, range ticks).
struct Hairline: View {
    var axis: Axis = .horizontal
    var color: Color = Theme.hair

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { ctx, size in
            let w = 1 / displayScale
            var path = Path()
            if axis == .horizontal {
                let y = PixelSnap.snap(size.height / 2, lineWidth: w, scale: displayScale)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            } else {
                let x = PixelSnap.snap(size.width / 2, lineWidth: w, scale: displayScale)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            ctx.stroke(path, with: .color(color), lineWidth: w)
        }
        .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Draws a `GlowLine` exactly inside a Swift Charts plot area (Charts keeps axes, selection
    /// and accessibility; the shader supplies the crisp line + grained fill).
    /// The chart's x domain must match the evenly spaced `line.values`.
    func mrhGlowUnderlay(_ line: GlowLine) -> some View {
        chartBackground { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    let rect = geo[anchor]
                    line
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
    }
}
