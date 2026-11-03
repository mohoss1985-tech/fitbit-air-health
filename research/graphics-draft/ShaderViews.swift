//  ShaderViews.swift — MRH1 v1.0 graphics layer (draft)
//
//  SwiftUI wrappers for Shaders.metal. iOS 17 APIs only (ShaderLibrary, .colorEffect,
//  TimelineView(.animation(minimumInterval:paused:)), onChange(of:_:) two-arg form).
//
//  Views:
//    AmbientOrbs(state:)   — Today header orbs. 30 fps cap, pauses off-screen / background,
//                            frozen + snap under Reduce Motion, 1.2 s OKLab morph between states.
//    GlowRing              — score ring/arc (Animatable progress).
//    GlowLine              — glowing line + area fill for a series (hairline-capable).
//    LivePulse             — the "latest sample" dot (pulse every 2 s, static under Reduce Motion).
//  Helpers:
//    OKLab                 — sRGB <-> OKLab/OKLCH, mixing, shader arguments, gradient stops.
//    Hairline / PixelSnap  — 1 device-pixel lines aligned to the pixel grid.
//    .mrhChartAxes()       — Swift Charts axis styling (hairline grid, quiet labels).
//    .mrhGlowUnderlay()    — puts a GlowLine exactly under a Swift Charts plot area.

import SwiftUI
import Charts

// MARK: - OKLab

/// OKLab colour (Björn Ottosson, 2020). L in 0...1, a/b roughly -0.4...0.4.
struct OKLab: Equatable, Sendable {
    var L: Float
    var a: Float
    var b: Float

    init(L: Float, a: Float, b: Float) {
        self.L = L
        self.a = a
        self.b = b
    }

    /// From a 0xRRGGBB sRGB hex value.
    init(hex: UInt32) {
        self.init(srgbR: Float((hex >> 16) & 0xFF) / 255,
                  g: Float((hex >> 8) & 0xFF) / 255,
                  b: Float(hex & 0xFF) / 255)
    }

    /// From gamma-encoded sRGB components in 0...1.
    init(srgbR r: Float, g: Float, b: Float) {
        let lr = OKLab.toLinear(r)
        let lg = OKLab.toLinear(g)
        let lb = OKLab.toLinear(b)
        let l: Float = cbrtf(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m: Float = cbrtf(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s: Float = cbrtf(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        let outL: Float = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let outA: Float = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let outB: Float = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        self.init(L: outL, a: outA, b: outB)
    }

    /// From OKLCH (lightness 0...1, chroma, hue in degrees) — matches CSS `oklch()`.
    init(oklchL l: Float, c: Float, hDegrees h: Float) {
        let rad = h * .pi / 180
        self.init(L: l, a: c * cosf(rad), b: c * sinf(rad))
    }

    /// Gamma-encoded sRGB components, clamped to gamut.
    var srgb: (r: Float, g: Float, b: Float) {
        let l1: Float = L + 0.3963377774 * a + 0.2158037573 * b
        let m1: Float = L - 0.1055613458 * a - 0.0638541728 * b
        let s1: Float = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l1 * l1 * l1
        let m = m1 * m1 * m1
        let s = s1 * s1 * s1
        let r: Float = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g: Float = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl: Float = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return (OKLab.toGamma(r), OKLab.toGamma(g), OKLab.toGamma(bl))
    }

    var color: Color {
        let c = srgb
        return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: 1)
    }

    /// Pass to a shader `float3` parameter.
    var arg: Shader.Argument { .float3(L, a, b) }

    static func mix(_ x: OKLab, _ y: OKLab, _ t: Float) -> OKLab {
        OKLab(L: x.L + (y.L - x.L) * t, a: x.a + (y.a - x.a) * t, b: x.b + (y.b - x.b) * t)
    }

    /// Multi-stop gradient sampled in OKLab, for SwiftUI / Swift Charts gradients that would
    /// otherwise interpolate in sRGB (muddy midpoints). Opacity ramps from `fromOpacity` to `toOpacity`.
    static func stops(_ x: OKLab, _ y: OKLab, count: Int = 8,
                      fromOpacity: Double = 1, toOpacity: Double = 1) -> [Gradient.Stop] {
        let n = max(count, 2)
        return (0..<n).map { i in
            let t = Float(i) / Float(n - 1)
            let o = fromOpacity + (toOpacity - fromOpacity) * Double(t)
            return Gradient.Stop(color: mix(x, y, t).color.opacity(o), location: CGFloat(t))
        }
    }

    private static func toLinear(_ v: Float) -> Float {
        v <= 0.04045 ? v / 12.92 : powf((v + 0.055) / 1.055, 2.4)
    }

    private static func toGamma(_ v: Float) -> Float {
        let c = min(max(v, 0), 1)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * powf(c, 1 / 2.4) - 0.055
    }
}

// MARK: - Palette tokens (moodboard + v1-direction)

enum GfxTokens {
    static let paper = OKLab(hex: 0xEDEBE7)
    static let paperNight = OKLab(hex: 0x141318)
    static let card = OKLab(hex: 0xFAF9F7)
    static let hair = OKLab(hex: 0xDFDBD5)
    static let hairNight = OKLab(hex: 0x33313B)
    static let ink = OKLab(hex: 0x151413)
    static let ember = OKLab(hex: 0xF0582A)
    static let peach = OKLab(hex: 0xF3A79E)
    static let iris = OKLab(hex: 0x8B88F0)
    static let good = OKLab(hex: 0x2F9D68)
    static let limit = OKLab(hex: 0xE6B820)
    static let danger = OKLab(hex: 0xD23A3A)
}

// MARK: - Ambient orbs

enum OrbState: Equatable, Sendable {
    case good, limit, danger, night, neutral
}

struct OrbPalette: Equatable, Sendable {
    var paper: OKLab
    var peach: OKLab
    var glow: OKLab
    var status: OKLab
    var ember: OKLab
    var night: Float
    var grain: Float

    init(_ state: OrbState) {
        switch state {
        case .good:
            self.init(paper: 0xEDEBE7, peach: 0xF3A79E, glow: 0xF6C9B8, status: 0x9AD3B2, ember: 0xF0582A)
        case .limit:
            self.init(paper: 0xEDEBE7, peach: 0xF3A79E, glow: 0xF6CFAE, status: 0xF2D46A, ember: 0xF0582A)
        case .danger:
            self.init(paper: 0xEDEBE7, peach: 0xF3A79E, glow: 0xF4B9B0, status: 0xE77A86, ember: 0xF0582A)
        case .neutral:
            self.init(paper: 0xEDEBE7, peach: 0xF3A79E, glow: 0xF6CDBB, status: 0xE9D9C8, ember: 0xF0582A)
        case .night:
            self.init(paper: 0x141318, peach: 0x6E4A63, glow: 0x3A2E48, status: 0x5B53A8, ember: 0xB8442A,
                      night: 1, grain: 0.016)
        }
    }

    private init(paper: UInt32, peach: UInt32, glow: UInt32, status: UInt32, ember: UInt32,
                 night: Float = 0, grain: Float = 0.010) {
        self.paper = OKLab(hex: paper)
        self.peach = OKLab(hex: peach)
        self.glow = OKLab(hex: glow)
        self.status = OKLab(hex: status)
        self.ember = OKLab(hex: ember)
        self.night = night
        self.grain = grain
    }

    static func mix(_ x: OrbPalette, _ y: OrbPalette, _ t: Float) -> OrbPalette {
        var p = y
        p.paper = .mix(x.paper, y.paper, t)
        p.peach = .mix(x.peach, y.peach, t)
        p.glow = .mix(x.glow, y.glow, t)
        p.status = .mix(x.status, y.status, t)
        p.ember = .mix(x.ember, y.ember, t)
        p.night = x.night + (y.night - x.night) * t
        p.grain = x.grain + (y.grain - x.grain) * t
        return p
    }
}

/// Peach / ember orbs behind the Today header; one orb carries the status colour.
/// Place it as a background of the header and let it extend under the status bar:
///     AmbientOrbs(state: .good).frame(height: 420).ignoresSafeArea(edges: .top)
struct AmbientOrbs: View {
    var state: OrbState
    /// Fraction of the view height where orbs start / finish dissolving into paper.
    var fade: ClosedRange<Float> = 0.38...0.95

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    @State private var from: OrbPalette?
    @State private var to: OrbPalette
    @State private var morphStart = Date.distantPast
    @State private var onScreen = true
    @State private var appeared = false

    private static let epoch = Date()
    private static let morphDuration: TimeInterval = 1.2
    /// Pleasing frozen composition for Reduce Motion / first frame.
    private static let frozenTime: Float = 8

    init(state: OrbState, fade: ClosedRange<Float> = 0.38...0.95) {
        self.state = state
        self.fade = fade
        _to = State(initialValue: OrbPalette(state))
    }

    private var paused: Bool {
        reduceMotion || !onScreen || !appeared || scenePhase != .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { context in
            let now = context.date
            let palette = palette(at: now)
            let time: Float = reduceMotion
                ? Self.frozenTime
                : Self.frozenTime + Float(now.timeIntervalSince(Self.epoch).truncatingRemainder(dividingBy: 10_000))
            let frame = Float(Int(now.timeIntervalSinceReferenceDate * 30) & 1023)

            Rectangle()
                .colorEffect(ShaderLibrary.mrhOrbField(
                    .boundingRect,
                    .float(time),
                    palette.paper.arg, palette.peach.arg, palette.glow.arg,
                    palette.status.arg, palette.ember.arg,
                    .float(palette.grain),
                    .float(fade.lowerBound), .float(fade.upperBound),
                    .float(Float(displayScale)),
                    .float(frame),
                    .float(palette.night)
                ))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        // Pause when scrolled fully above the screen (header lives at the top of Today).
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).maxY > 0
        } action: { visible in
            onScreen = visible
        }
        .onChange(of: state) { _, newState in
            let now = Date()
            from = reduceMotion ? nil : palette(at: now)   // Reduce Motion: snap, no morph
            to = OrbPalette(newState)
            morphStart = now
        }
    }

    private func palette(at now: Date) -> OrbPalette {
        guard let from else { return to }
        let k = min(max(now.timeIntervalSince(morphStart) / Self.morphDuration, 0), 1)
        return OrbPalette.mix(from, to, Float(Self.easeInOut(k)))
    }

    /// Approximates cubic-bezier(0.77, 0, 0.175, 1) (motion spec "morph").
    private static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}

// MARK: - Glow ring

/// Score ring with a crisp SDF edge, OKLab gradient along the arc and a soft glow at the head.
/// `progress` is Animatable: wrap changes in `withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.6))`.
/// The ring is inset by 1.5 x lineWidth inside its frame so the glow is not clipped.
struct GlowRing: View, Animatable {
    var progress: Double
    var start: OKLab
    var end: OKLab
    var track: OKLab = GfxTokens.hair
    var lineWidth: CGFloat = 10
    var trackOpacity: Float = 1
    var glow: Float = 0.6
    var night: Bool = false

    @Environment(\.displayScale) private var displayScale

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Rectangle()
            .colorEffect(ShaderLibrary.mrhRingGlow(
                .boundingRect,
                .float(Float(progress)),
                .float(Float(lineWidth)),
                start.arg, end.arg, track.arg,
                .float(trackOpacity),
                .float(glow),
                .float(Float(displayScale)),
                .float(night ? 1 : 0)
            ))
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

// MARK: - Glow line

/// Glowing line + local gradient area fill drawn by `mrhChartLine`.
/// Values are evenly spaced in x; `nil` makes a gap ("Not sent", sync holes).
struct GlowLine: View {
    var values: [Double?]
    var domain: ClosedRange<Double>
    var color: OKLab
    /// Points. 0 = one device-pixel hairline.
    var lineWidth: CGFloat = 1.5
    var fillOpacity: Float = 0.20
    var glow: Float = 0.5
    /// Keeps the stroke and glow from clipping at the top / bottom edge (fraction of height).
    var verticalInset: Double = 0.06
    /// Upper bound on points sent to the GPU (bucket-averaged above this).
    var maxPoints: Int = 240

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let ys = normalised()
        let width: CGFloat = lineWidth <= 0 ? 1 / displayScale : lineWidth
        Rectangle()
            .colorEffect(ShaderLibrary.mrhChartLine(
                .boundingRect,
                .floatArray(ys),
                .float(Float(width)),
                color.arg,
                .float(fillOpacity),
                .float(glow),
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
        // The shader needs >= 2 entries.
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

// MARK: - Live pulse

/// The glowing "latest sample" point. Pulses every 2 s (ease-out ring), static halo under Reduce Motion.
struct LivePulse: View {
    var color: Color
    var diameter: CGFloat = 7
    var ring: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || scenePhase != .active)) { context in
            let raw = reduceMotion ? 0.35 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.0) / 2.0
            let phase = 1 - pow(1 - raw, 3)                    // ease-out
            ZStack {
                Circle()
                    .fill(color.opacity(reduceMotion ? 0.18 : 0.28 * (1 - phase)))
                    .frame(width: diameter * (1 + 2.6 * phase), height: diameter * (1 + 2.6 * phase))
                Circle()
                    .fill(color)
                    .frame(width: diameter, height: diameter)
                    .overlay(Circle().strokeBorder(ring, lineWidth: 1.5))
                    .shadow(color: color.opacity(0.5), radius: 4)
            }
            .frame(width: diameter * 3.6, height: diameter * 3.6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Crisp line helpers

enum PixelSnap {
    /// Centre of a line of `lineWidth` points aligned to the device-pixel grid.
    /// Odd pixel widths sit on pixel centres, even widths on pixel edges.
    static func snap(_ v: CGFloat, lineWidth: CGFloat, scale: CGFloat) -> CGFloat {
        let px = (lineWidth * scale).rounded()
        let base = (v * scale).rounded(.down)
        let offset: CGFloat = Int(px) % 2 == 1 ? 0.5 : 0
        return (base + offset) / scale
    }
}

/// A one-device-pixel line, snapped to the pixel grid (use for dividers, baselines, range ticks).
struct Hairline: View {
    var axis: Axis = .horizontal
    var color: Color = GfxTokens.hair.color

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

// MARK: - Swift Charts styling

struct MRHChartAxes: ViewModifier {
    var hair: Color = GfxTokens.hair.color
    var label: Color = Color(red: 0x77 / 255, green: 0x72 / 255, blue: 0x6C / 255)
    var xCount: Int = 4
    var yCount: Int = 3

    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        let w = 1 / displayScale
        return content
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: xCount)) { _ in
                    AxisValueLabel()
                        .font(.system(size: 11, weight: .regular).monospacedDigit())
                        .foregroundStyle(label)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: yCount)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: w))
                        .foregroundStyle(hair)
                    AxisValueLabel()
                        .font(.system(size: 11, weight: .regular).monospacedDigit())
                        .foregroundStyle(label)
                }
            }
    }
}

extension View {
    /// Hairline y grid, no x grid, quiet tabular labels. Pair with marks styled as:
    /// `LineMark(...).interpolationMethod(.monotone).lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))`
    /// `AreaMark(...).foregroundStyle(LinearGradient(stops: OKLab.stops(c, c, fromOpacity: 0.22, toOpacity: 0), startPoint: .top, endPoint: .bottom))`
    func mrhChartAxes(xCount: Int = 4, yCount: Int = 3) -> some View {
        modifier(MRHChartAxes(xCount: xCount, yCount: yCount))
    }

    /// Draws a `GlowLine` exactly inside a Swift Charts plot area (Charts keeps axes, labels,
    /// selection and accessibility; the shader supplies crisp glow + fill).
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

// MARK: - Preview

#Preview("Graphics draft") {
    struct Demo: View {
        @State private var state: OrbState = .good
        @State private var progress = 0.84
        private let hr: [Double?] = (0..<96).map { (i: Int) -> Double? in
            if i > 60 && i < 66 { return nil }
            let wave: Double = 9 * sin(Double(i) / 7)
            return 62 + wave + Double(i % 5)
        }
        var body: some View {
            ZStack(alignment: .top) {
                GfxTokens.paper.color.ignoresSafeArea()
                AmbientOrbs(state: state).frame(height: 420).ignoresSafeArea(edges: .top)
                VStack(spacing: 24) {
                    Picker("State", selection: $state) {
                        Text("Good").tag(OrbState.good)
                        Text("Limit").tag(OrbState.limit)
                        Text("Danger").tag(OrbState.danger)
                        Text("Night").tag(OrbState.night)
                    }
                    .pickerStyle(.segmented)
                    GlowRing(progress: progress, start: GfxTokens.good, end: OKLab(hex: 0x4CC789))
                        .frame(width: 140)
                        .onTapGesture {
                            withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.6)) {
                                progress = progress > 0.5 ? 0.32 : 0.92
                            }
                        }
                    ZStack(alignment: .trailing) {
                        GlowLine(values: hr, domain: 50...90, color: GfxTokens.ember)
                        LivePulse(color: GfxTokens.ember.color).offset(x: 10)
                    }
                    .frame(height: 140)
                    Hairline()
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
            }
        }
    }
    return Demo()
}
