import SwiftUI

// MRH1 v1 shared components (DESIGN_SPEC §8). v0.4 names (RingView, FlagPill, RangeBar, Card,
// MetricRow, Sparkline) keep their old initialisers and render in the v1 style.

// MARK: - Card

/// Fill only: no border, no shadow. Radius 28, padding 20, inner spacing 12.
struct Card<Content: View>: View {
    var padding: CGFloat = Space.gutter
    var spacing: CGFloat = Space.m
    @ViewBuilder var content: Content

    init(padding: CGFloat = Space.gutter, spacing: CGFloat = Space.m, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// MARK: - Section label

/// Sentence case, `label` style, graphite. Never all caps.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .typo(.label)
            .foregroundStyle(Theme.graphite)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Pill picker (black pill segmented)

/// Segmented control: hair track, selected segment ink-filled with card-coloured text.
/// Switching cross-fades only (no sliding), per the range-switch rule.
struct PillPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    init(selection: Binding<T>, options: [T], label: @escaping (T) -> String) {
        self._selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { opt in
                let on = opt == selection
                Button {
                    if !on { Motion.animate(Motion.crossfade) { selection = opt } }
                } label: {
                    Text(label(opt))
                        .typo(.label)
                        .lineLimit(1)
                        .foregroundStyle(on ? Theme.card : Theme.graphite)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Capsule().fill(Theme.ink).opacity(on ? 1 : 0))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(label(opt))
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(Space.xs)
        .background(Capsule().fill(Theme.card).overlay(Capsule().strokeBorder(Theme.hair, lineWidth: 0.5)))
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Round icon button (44 pt frosted)

/// 44 pt round button: ultraThinMaterial + 0.5 pt hair stroke + 2-layer ink shadow.
/// `filled` = ink-filled (selected tab).
struct RoundIconButton: View {
    let systemName: String
    let label: String
    var filled: Bool = false
    var size: CGFloat = 44
    let action: () -> Void

    init(systemName: String, label: String, filled: Bool = false, size: CGFloat = 44, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.filled = filled
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(filled ? Theme.card : Theme.ink)
                .frame(width: size, height: size)
                .background {
                    if filled {
                        Circle().fill(Theme.ink)
                    } else {
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().strokeBorder(Theme.hair, lineWidth: 0.5))
                            .shadow(color: Theme.ink.opacity(0.04), radius: 2, y: 1)
                            .shadow(color: Theme.ink.opacity(0.06), radius: 24, y: 8)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(filled ? .isSelected : [])
    }
}

// MARK: - Status chip

/// Result chip: In range · Watch · Out of range, chip-bg / chip-text pairs, radius 8.
struct StatusChip: View {
    let tier: StatusTier?
    var accessibilityDetail: String? = nil
    /// Green but honest: a better-than-usual value says "Above usual" / "Below usual", not "In range".
    var wordOverride: String? = nil

    init(flag: Flag) { self.tier = flag.statusTier }
    init(tier: StatusTier?) { self.tier = tier }
    /// Direction-aware (better-than-usual stays In range; >1 SD past a concern edge = Out of range).
    init(state: MetricState) {
        self.tier = state.statusTier
        if state.flag == .high { accessibilityDetail = "above your usual range" }
        if state.flag == .low { accessibilityDetail = "below your usual range" }
        if state.hasData, !state.isConcern {
            if state.flag == .high { wordOverride = "Above usual" }
            if state.flag == .low { wordOverride = "Below usual" }
        }
    }

    var body: some View {
        if let tier {
            let c = tier.chipColors
            HStack(spacing: Space.xs) {
                Circle().fill(tier.fill).frame(width: 6, height: 6)
                Text(wordOverride ?? tier.word).typo(.label).foregroundStyle(c.text)
            }
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xs)
            .background(c.bg, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDetail.map { "\(wordOverride ?? tier.word), \($0)" } ?? (wordOverride ?? tier.word))
        }
    }
}

// MARK: - Missing-data label

enum NotSentKind: Hashable {
    case notSent, waiting, noReading

    var text: String {
        switch self {
        case .notSent: return "Not sent by Google Health"
        case .waiting: return "Waiting for sync"
        case .noReading: return "No reading"
        }
    }
    var short: String {
        switch self {
        case .notSent: return "Not sent"
        case .waiting: return "Waiting for sync"
        case .noReading: return "No reading"
        }
    }

    /// HRV, skin temperature and VO2 max are never sent by Google Health.
    static func forMetric(_ id: MetricID) -> NotSentKind {
        switch id {
        case .hrv, .skinTemp: return .notSent
        default: return .waiting
        }
    }
}

/// The three missing states, caption graphite. Never a zero.
struct NotSentLabel: View {
    typealias Kind = NotSentKind
    let kind: NotSentKind
    var short: Bool = false

    init(kind: NotSentKind, short: Bool = false) {
        self.kind = kind
        self.short = short
    }

    var body: some View {
        Text(short ? kind.short : kind.text)
            .typo(.caption)
            .foregroundStyle(Theme.graphite)
            .accessibilityLabel(kind.text)
    }
}

// MARK: - Freshness chip

/// "Synced 23 min ago". Turns yellow (limit chip) after 3 h, with a clock glyph.
struct FreshnessChip: View {
    let date: Date?
    var staleAfter: TimeInterval = 3 * 3600
    /// "Synced" = age of the newest data; "Checked" = when the app last asked Apple Health.
    var verb: String = "Synced"

    init(date: Date?, staleAfter: TimeInterval = 3 * 3600, verb: String = "Synced") {
        self.date = date
        self.staleAfter = staleAfter
        self.verb = verb
    }

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let stale = date.map { ctx.date.timeIntervalSince($0) > staleAfter } ?? true
            HStack(spacing: Space.xs) {
                if stale { Image(systemName: "clock").font(.system(size: 11, weight: .regular)) }
                Text(Self.text(date, now: ctx.date, verb: verb)).typo(.micro)
            }
            .foregroundStyle(stale ? Theme.limitText : Theme.graphite)
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xs)
            .background(stale ? Theme.limitBg : Theme.hair.opacity(0.6),
                        in: Capsule())
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.text(date, now: ctx.date, verb: verb) + (stale ? ", data may be out of date" : ""))
        }
    }

    static func text(_ date: Date?, now: Date = .now, verb: String = "Synced") -> String {
        guard let date else { return "Waiting for sync" }
        let mins = max(0, Int(now.timeIntervalSince(date) / 60))
        if mins < 1 { return "\(verb) just now" }
        if mins < 60 { return "\(verb) \(mins) min ago" }
        let hours = mins / 60
        if hours < 24 { return "\(verb) \(hours) h ago" }
        return verb + " " + date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Shared range geometry

private enum RangeMath {
    /// Padded domain around band + value so both fit with breathing room.
    static func domain(value: Double?, band: ClosedRange<Double>?) -> ClosedRange<Double> {
        var lo = band?.lowerBound ?? value ?? 0
        var hi = band?.upperBound ?? value ?? 1
        if let v = value { lo = min(lo, v); hi = max(hi, v) }
        let span = max(hi - lo, abs(hi) * 0.1, 1)
        return (lo - span * 0.6)...(hi + span * 0.6)
    }

    static func x(_ v: Double, in d: ClosedRange<Double>, width w: CGFloat) -> CGFloat {
        CGFloat((v - d.lowerBound) / max(d.upperBound - d.lowerBound, 0.0001)) * w
    }
}

// MARK: - Baseline ribbon (brand shape)

/// Paper track, personal normal = ink 10 % band, today = ember dot that turns status colour
/// only when outside the band (direction-aware via `Insights.direction` / `MetricState.statusTier`).
struct BaselineRibbon: View {
    let value: Double?
    let band: ClosedRange<Double>?
    /// Dot colour when outside the band (nil = ember).
    let outsideColor: Color?
    var height: CGFloat = 10
    var a11y: String

    init(state: MetricState, height: CGFloat = 10) {
        self.value = state.latest?.value
        self.band = state.band
        self.height = height
        let inside = state.flag == .normal
        self.outsideColor = inside ? nil : (state.statusTier?.fill ?? Theme.ember)
        if state.hasData {
            let pos = state.flag == .high ? "above" : (state.flag == .low ? "below" : "inside")
            self.a11y = "\(state.valueText) \(state.id.info.unit), \(pos) your usual range \(state.yourRangeText)"
        } else {
            self.a11y = "No value"
        }
    }

    /// Generic form (Live 7D/30D, sheets).
    init(value: Double?, band: ClosedRange<Double>?, outsideColor: Color? = nil, height: CGFloat = 10) {
        self.value = value
        self.band = band
        self.outsideColor = outsideColor
        self.height = height
        if let value, let band {
            let pos = value > band.upperBound ? "above" : (value < band.lowerBound ? "below" : "inside")
            self.a11y = "\(pos) your usual range"
        } else {
            self.a11y = "No value"
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let d = RangeMath.domain(value: value, band: band)
            let dot = height + 2
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.paper)
                    .overlay(Capsule().strokeBorder(Theme.hair, lineWidth: 0.5))
                    .frame(height: height)
                if let band {
                    let x0 = RangeMath.x(band.lowerBound, in: d, width: w)
                    let x1 = RangeMath.x(band.upperBound, in: d, width: w)
                    Capsule().fill(Theme.bandFill)
                        .frame(width: max(x1 - x0, height), height: height)
                        .offset(x: x0)
                }
                if let value {
                    let inside = band.map { $0.contains(value) } ?? true
                    Circle()
                        // Same colour as the status chip: green inside your range, never an orange that reads as a warning.
                        .fill(inside ? Theme.good : (outsideColor ?? Theme.ember))
                        .overlay(Circle().strokeBorder(Theme.card, lineWidth: 2))
                        .frame(width: dot, height: dot)
                        .offset(x: min(max(RangeMath.x(value, in: d, width: w) - dot / 2, 0), w - dot))
                }
            }
            .frame(height: dot)
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 2)
        .motionSafe(Motion.morph, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }
}

// MARK: - Dot-matrix range strip

/// 4 pt dots on a 6.5 pt pitch. Dots inside the band step through the status colour at
/// 30 → 100 %; outside dots are hair. Current value = ink dot with a pill label.
struct RangeStrip: View {
    let value: Double?
    let band: ClosedRange<Double>?
    let valueLabel: String
    let tint: Color
    let a11y: String

    init(state: MetricState) {
        self.value = state.latest?.value
        self.band = state.band
        self.valueLabel = state.valueText
        self.tint = (state.statusTier ?? .inRange).fill
        if state.hasData {
            self.a11y = "\(state.valueText) \(state.id.info.unit). Your range \(state.yourRangeText). \((state.statusTier ?? .inRange).word)"
        } else {
            self.a11y = "No value"
        }
    }

    init(value: Double?, band: ClosedRange<Double>?, valueLabel: String, tint: Color = Theme.good) {
        self.value = value
        self.band = band
        self.valueLabel = valueLabel
        self.tint = tint
        self.a11y = value == nil ? "No value" : valueLabel
    }

    private let dot: CGFloat = 4
    private let pitch: CGFloat = 6.5
    private let labelH: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let d = RangeMath.domain(value: value, band: band)
            let count = max(Int((w - dot) / pitch) + 1, 2)
            let rowY = labelH + Space.xs + dot / 2 + 2
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    let bx0 = band.map { RangeMath.x($0.lowerBound, in: d, width: w) }
                    let bx1 = band.map { RangeMath.x($0.upperBound, in: d, width: w) }
                    for i in 0..<count {
                        let cx = dot / 2 + CGFloat(i) * pitch
                        let r = CGRect(x: cx - dot / 2, y: rowY - dot / 2, width: dot, height: dot)
                        var c = Theme.hair
                        if let bx0, let bx1, cx >= bx0, cx <= bx1 {
                            let t = (cx - bx0) / max(bx1 - bx0, 1)
                            c = tint.opacity(0.3 + 0.7 * Double(t))
                        }
                        ctx.fill(Path(ellipseIn: r), with: .color(c))
                    }
                }
                if let value {
                    let x = min(max(RangeMath.x(value, in: d, width: w), 5), w - 5)
                    Circle()
                        .fill(Theme.ink)
                        .overlay(Circle().strokeBorder(Theme.card, lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .position(x: x, y: rowY)
                    Text(valueLabel)
                        .typo(.micro)
                        .foregroundStyle(Theme.card)
                        .padding(.horizontal, Space.s)
                        .frame(height: labelH)
                        .background(Capsule().fill(Theme.ink))
                        .fixedSize()
                        .position(x: min(max(x, 28), w - 28), y: labelH / 2)
                }
            }
        }
        .frame(height: labelH + Space.xs + dot + 6)
        .motionSafe(Motion.morph, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }
}

// MARK: - Tick ring

/// 48 radial ticks (2 × 7 pt at 160 pt, scaled), result colour vs hair. Ticks light up one after
/// another, 8 ms apart, only when `animateOnAppear` (callers pass `TickRing.firstOpenToday(...)`).
struct TickRing<Center: View>: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    var ticks: Int = 48
    var animateOnAppear: Bool
    var accessibilityName: String?
    @ViewBuilder var center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit: Int = -1
    @State private var runner: Task<Void, Never>?

    init(progress: Double, color: Color, size: CGFloat, ticks: Int = 48, animateOnAppear: Bool,
         accessibilityName: String? = nil, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.color = color
        self.size = size
        self.ticks = ticks
        self.animateOnAppear = animateOnAppear
        self.accessibilityName = accessibilityName
        self.center = center()
    }

    private var target: Int { Int((max(0, min(progress, 1)) * Double(ticks)).rounded()) }

    var body: some View {
        let shown = lit < 0 ? (animateOnAppear && !reduceMotion ? 0 : target) : lit
        ZStack {
            Canvas { ctx, sz in
                let scale = max(sz.width / 160, 0.35)
                let len = 7 * scale
                let wid = max(2 * scale, 1.25)
                let r = sz.width / 2 - wid / 2
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                for i in 0..<ticks {
                    let a = Double(i) / Double(ticks) * 2 * .pi - .pi / 2
                    let p0 = CGPoint(x: c.x + cos(a) * (r - len), y: c.y + sin(a) * (r - len))
                    let p1 = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                    var path = Path()
                    path.move(to: p0); path.addLine(to: p1)
                    ctx.stroke(path, with: .color(i < shown ? color : Theme.hair),
                               style: StrokeStyle(lineWidth: wid, lineCap: .round))
                }
            }
            center
        }
        .frame(width: size, height: size)
        .onAppear {
            guard lit < 0 else { return }
            if animateOnAppear && !reduceMotion { run(from: 0, to: target) } else { lit = target }
        }
        .onChange(of: target) { _, new in
            run(from: max(lit, 0), to: new)
        }
        .onDisappear { runner?.cancel() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityName ?? "Score")
        .accessibilityValue("\(Int((max(0, min(progress, 1)) * 100).rounded())) percent")
    }

    private func run(from: Int, to: Int) {
        runner?.cancel()
        if reduceMotion || from == to { lit = to; return }
        lit = from
        runner = Task { @MainActor in
            let step = to > from ? 1 : -1
            var i = from
            while i != to {
                try? await Task.sleep(nanoseconds: 8_000_000)
                if Task.isCancelled { return }
                i += step
                lit = i
            }
        }
    }
}

extension TickRing where Center == EmptyView {
    init(progress: Double, color: Color, size: CGFloat, ticks: Int = 48, animateOnAppear: Bool,
         accessibilityName: String? = nil) {
        self.init(progress: progress, color: color, size: size, ticks: ticks, animateOnAppear: animateOnAppear,
                  accessibilityName: accessibilityName) { EmptyView() }
    }
}

enum TickRingGate {
    /// true the first time it is called for `key` on a calendar day, false afterwards.
    static func firstOpenToday(_ key: String) -> Bool {
        let k = "mrh1.ringAnim.\(key)"
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        if UserDefaults.standard.double(forKey: k) == today { return false }
        UserDefaults.standard.set(today, forKey: k)
        return true
    }
}

// MARK: - v0.4 RingView (now a tick ring)

struct RingView: View {
    let progress: Double
    let color: Color
    let track: Color
    var lineWidth: CGFloat = 9
    var delay: Double = 0

    var body: some View {
        GeometryReader { geo in
            TickRing(progress: progress, color: color, size: min(geo.size.width, geo.size.height),
                     animateOnAppear: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Strain capsule gauge

/// Capsule gauge 0 – 21: ember → peach fill with print grain, target zone = two ink ticks.
struct StrainGauge: View {
    let value: Double
    let target: ClosedRange<Double>
    var maxValue: Double = 21
    var height: CGFloat = 14

    init(value: Double, target: ClosedRange<Double>, maxValue: Double = 21, height: CGFloat = 14) {
        self.value = value
        self.target = target
        self.maxValue = maxValue
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x: (Double) -> CGFloat = { CGFloat(max(0, min($0 / maxValue, 1))) * w }
            let tickH = height + Space.s
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hair).frame(height: height)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.ember, Color.oklabMix(Theme.ember, Theme.peach, t: 0.5), Theme.peach],
                                         startPoint: .leading, endPoint: .trailing))
                    .printGrain(amount: 0.03)
                    .frame(width: max(x(value), value > 0 ? height : 0), height: height)
                ForEach([target.lowerBound, target.upperBound], id: \.self) { t in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.ink)
                        .frame(width: 2, height: tickH)
                        .offset(x: x(t) - 1)
                }
            }
            .frame(height: tickH)
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + Space.s)
        .motionSafe(Motion.morph, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strain \(String(format: "%.1f", locale: .current, value)) of \(Int(maxValue))")
        .accessibilityValue("Target \(Int(target.lowerBound)) to \(Int(target.upperBound))"
                            + (target.contains(value) ? ", in target" : (value < target.lowerBound ? ", below target" : ", above target")))
    }
}

// MARK: - Sparkline

/// 1.75 pt line, round caps, monotone cubic (no overshoot), small end dot. Line only, no fill.
struct Sparkline: View {
    let values: [Double]
    var color: Color = Theme.ink

    init(values: [Double], color: Color = Theme.ink) {
        self.values = values
        self.color = color
    }

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2, let lo = values.min(), let hi = values.max() {
                let span = max(hi - lo, 0.0001)
                let pts = values.enumerated().map { i, v in
                    CGPoint(x: 2 + (geo.size.width - 4) * CGFloat(i) / CGFloat(values.count - 1),
                            y: geo.size.height * (1 - CGFloat((v - lo) / span)) * 0.8 + geo.size.height * 0.1)
                }
                ZStack {
                    Self.monotonePath(pts)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                    if let last = pts.last {
                        Circle().fill(color).frame(width: 4, height: 4).position(last)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(values.isEmpty ? "No trend" : "Trend, \(values.count) days")
    }

    /// Fritsch–Carlson monotone cubic interpolation.
    static func monotonePath(_ p: [CGPoint]) -> Path {
        var path = Path()
        guard p.count > 1 else { return path }
        let n = p.count
        var d = [CGFloat](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) { d[i] = (p[i + 1].y - p[i].y) / max(p[i + 1].x - p[i].x, 0.0001) }
        var m = [CGFloat](repeating: 0, count: n)
        m[0] = d[0]; m[n - 1] = d[n - 2]
        if n > 2 {
            for i in 1..<(n - 1) { m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2 }
        }
        for i in 0..<(n - 1) where d[i] == 0 { m[i] = 0; m[i + 1] = 0 }
        for i in 0..<(n - 1) where d[i] != 0 {
            let a = m[i] / d[i], b = m[i + 1] / d[i]
            let s = a * a + b * b
            if s > 9 { let t = 3 / s.squareRoot(); m[i] = t * a * d[i]; m[i + 1] = t * b * d[i] }
        }
        path.move(to: p[0])
        for i in 0..<(n - 1) {
            let h = (p[i + 1].x - p[i].x) / 3
            path.addCurve(to: p[i + 1],
                          control1: CGPoint(x: p[i].x + h, y: p[i].y + m[i] * h),
                          control2: CGPoint(x: p[i + 1].x - h, y: p[i + 1].y - m[i + 1] * h))
        }
        return path
    }
}

// MARK: - v0.4 FlagPill (now a status chip)

struct FlagPill: View {
    let flag: Flag
    var color: Color? = nil

    var body: some View {
        if flag != .none { StatusChip(flag: flag) }
    }
}

// MARK: - v0.4 RangeBar (now a baseline ribbon)

struct RangeBar: View {
    let value: Double?
    let band: ClosedRange<Double>?
    let flag: Flag
    var height: CGFloat = 12
    var dotColor: Color? = nil

    var body: some View {
        BaselineRibbon(value: value, band: band, outsideColor: dotColor ?? flag.statusTier?.fill, height: height)
    }
}

// MARK: - Metric row

/// label · value + unit · status chip · baseline ribbon · 7-day sparkline. Taps open MetricSheet.
struct MetricRow: View {
    private let id: MetricID
    private let fixedState: MetricState?
    private let onTap: (() -> Void)?

    @State private var sheet: MetricState?

    /// v1: reads the state from `HealthStore` in the environment; presents MetricSheet itself.
    init(id: MetricID) {
        self.id = id
        self.fixedState = nil
        self.onTap = nil
    }

    /// v0.4: explicit state + tap handler.
    init(state: MetricState, onTap: @escaping () -> Void) {
        self.id = state.id
        self.fixedState = state
        self.onTap = onTap
    }

    var body: some View {
        if let fixedState {
            row(fixedState)
        } else {
            EnvRow(id: id) { s in row(s) }
        }
    }

    private func row(_ state: MetricState) -> some View {
        Button {
            if let onTap { onTap() } else { sheet = state }
        } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.id.info.name).typo(.body).foregroundStyle(Theme.ink)
                        Text(state.id.info.sub).typo(.caption).foregroundStyle(Theme.graphite).lineLimit(1)
                    }
                    Spacer(minLength: Space.s)
                    if state.hasData {
                        ValueText(value: state.valueText, unit: state.id.info.unit, size: .headline)
                        StatusChip(state: state)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("—").typo(.headline).foregroundStyle(Theme.graphite)
                            NotSentLabel(kind: NotSentKind.forMetric(state.id), short: true)
                        }
                    }
                }
                if state.hasData {
                    HStack(spacing: Space.m) {
                        BaselineRibbon(state: state)
                        Sparkline(values: state.spark, color: Theme.ink).frame(width: 64, height: 20)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Theme.graphite2)
                    }
                }
            }
            .padding(.vertical, Space.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .sheet(item: $sheet) { MetricSheet(state: $0) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.hasData
            ? "\(state.id.info.name), \(state.valueText) \(state.id.info.unit), \((state.statusTier ?? .inRange).word)"
            : "\(state.id.info.name), \(NotSentKind.forMetric(state.id).text)")
        .accessibilityHint("Shows what it means")
        .accessibilityAddTraits(.isButton)
    }
}

/// Reads HealthStore only in the id-based MetricRow, so the v0.4 init needs no environment.
private struct EnvRow<Row: View>: View {
    let id: MetricID
    @ViewBuilder let row: (MetricState) -> Row
    @Environment(HealthStore.self) private var health

    var body: some View { row(health.state(id)) }
}

// MARK: - Sync now

/// Google Health only pushes to Apple Health when it runs. When the newest data is over an hour
/// old, this opens Google Health so it syncs; MRH1 re-reads Apple Health when you come back.
struct SyncNowButton: View {
    let date: Date?
    var staleAfter: TimeInterval = 3600
    @State private var couldNotOpen = false

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            if !Demo.isOn, date.map({ ctx.date.timeIntervalSince($0) > staleAfter }) ?? true {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Button(action: open) {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12, weight: .semibold))
                            Text("Sync now").typo(.label)
                        }
                        .foregroundStyle(Theme.paper)
                        .padding(.horizontal, Space.m)
                        .padding(.vertical, Space.s)
                        .background(Theme.ink, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityHint("Opens Google Health so it sends its latest data to Apple Health")
                    Text(couldNotOpen
                         ? "Open Google Health yourself, then come back. New data shows up here on its own."
                         : "Opens Google Health so it sends new data. Come back and MRH1 updates.")
                        .typo(.caption).foregroundStyle(Theme.graphite)
                }
            }
        }
    }

    private func open() {
        // Google Health is the renamed Fitbit app and still answers to fitbit://.
        guard let url = URL(string: "fitbit://") else { return }
        UIApplication.shared.open(url) { ok in couldNotOpen = !ok }
    }
}
