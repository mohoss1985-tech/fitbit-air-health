# Wave 1 — Agent A: Theme · Typography · Motion · Components

Files: `MRH1/Theme.swift`, `MRH1/Typography.swift`, `MRH1/Motion.swift`, `MRH1/Components.swift`.
All four compile with 0 errors and 0 warnings (build/A). The only remaining build error is `ContentView.swift:37` (switch must be exhaustive), which is not in A's files.

## Theme.swift

```swift
enum Theme {  // all static let Color, adaptive light/dark
  paper, card, ink, graphite, graphite2, hair,
  ember, emberInk, peach, iris,
  good, goodBg, goodText, limit, limitBg, limitText, danger, dangerBg, dangerText,
  stageDeep, stageCore, stageREM, stageAwake,
  bandFill   // ink 10 %, the personal-normal band
  ink2       // alias helper (light #3E3A36 / dark #B4AEA7)
  // v0.4 aliases:
  background=paper, cardRaised=card, inset=paper, line=hair, text2=ink2, text3=graphite,
  recovery=good, recoveryTrack=hair, strain=ember, strainTrack=hair, sleep=iris, sleepTrack=hair,
  warn=limit, low=limit, bad=danger, heart=ember, lungs=graphite, activity=ember,
  stageLight=stageCore, band=bandFill, bandEdge=graphite2
}
enum Space  { xs=4, s=8, m=12, l=16, gutter=20, xl=24, section=32, xxl=48, cardPadding=20, cardGap=12 }  // CGFloat
enum Radius { card=28, inner=16, chip=8, bar=2 }                                                      // CGFloat

enum StatusTier: Hashable { case inRange, watch, outOfRange
  var word: String        // "In range" / "Watch" / "Out of range"
  var fill: Color         // good / limit / danger
  var chipColors: (bg: Color, text: Color) }

extension Flag {
  var chipColors: (bg: Color, text: Color)
  var statusTier: StatusTier?            // normal→.inRange, high/low→.watch, none→nil
}
extension MetricState {
  var bandDistance: Double               // SDs beyond band edge (0 inside)
  var statusTier: StatusTier?            // direction-aware: better than usual→.inRange;
                                         // concern→.watch, >1 SD past edge→.outOfRange; no data→nil
}
extension Color {
  init(hex: UInt32)
  init(light: UInt32, dark: UInt32, alpha: CGFloat = 1, darkAlpha: CGFloat? = nil)
  init(light: Color, dark: Color)
}
extension UIColor { convenience init(hex: UInt32, alpha: CGFloat = 1) }
```
Dark values: base #151413, card #1F1D1B, ink #F2EFEA, graphite #B4AEA7 (ink2), graphite2 #5E5953, hair #2E2B28. Status chip bgs in dark = the status hue at 18 % alpha with light text. No blue anywhere.

## Typography.swift

```swift
enum Typo {
  static var display, title, metric, headline, body, label, caption, micro, mono: Font  // computed
  enum Role { case display, title, metric, headline, body, label, caption, micro, mono }
  static func font(_ r: Role) -> Font
  static func tracking(_ r: Role) -> CGFloat
}
extension View {
  func typo(_ role: Typo.Role) -> some View   // font + tracking: prefer this over .font(Typo.x)
  func unitStyle() -> some View               // caption, graphite
}
struct ValueText: View {
  enum Size { case display, metric, headline }
  init(value: String, unit: String = "", size: Size = .metric, color: Color = Theme.ink)
}
```
Fonts are built with UIFontMetrics, so Dynamic Type scales them. display and metric use the rounded design, and every role except mono uses `.monospacedDigit()`. ValueText aligns value and unit on the baseline with a 2 pt gap and uses `.numericText()`. For "—" it greys the value and hides the unit.

## Motion.swift

```swift
enum Motion {
  static let press, enter, morph, crossfade, reduced: Animation
  static let pressScale: CGFloat = 0.97, enterScale: CGFloat = 0.96
  static func safe(_ anim: Animation, reduceMotion: Bool) -> Animation
  static func animate<R>(_ anim: Animation, _ body: () throws -> R) rethrows -> R   // withAnimation honouring Reduce Motion
}
extension AnyTransition { static var mrhEnter: AnyTransition }       // scale 0.96 + opacity
struct PressStyle: ButtonStyle {}                                     // also `.buttonStyle(.press)`
extension View {
  func motionSafe(_ anim: Animation) -> some View                     // re-times animated transactions; fade under Reduce Motion
  func motionSafe<V: Equatable>(_ anim: Animation, value: V) -> some View
}
```

## Components.swift

```swift
struct Card<Content: View>      init(padding: CGFloat = Space.gutter, spacing: CGFloat = Space.m, @ViewBuilder content: () -> Content)
struct SectionLabel             init(_ text: String)
struct PillPicker<T: Hashable>  init(selection: Binding<T>, options: [T], label: @escaping (T) -> String)
struct RoundIconButton          init(systemName: String, label: String, filled: Bool = false, size: CGFloat = 44, action: @escaping () -> Void)
struct StatusChip               init(flag: Flag) · init(tier: StatusTier?) · init(state: MetricState)
enum   NotSentKind              .notSent / .waiting / .noReading; var text, short; static func forMetric(_ id: MetricID) -> NotSentKind
struct NotSentLabel             typealias Kind = NotSentKind; init(kind: NotSentKind, short: Bool = false)
struct FreshnessChip            init(date: Date?, staleAfter: TimeInterval = 3 * 3600); static func text(_ date: Date?, now: Date = .now) -> String
struct BaselineRibbon           init(state: MetricState, height: CGFloat = 10)
                                init(value: Double?, band: ClosedRange<Double>?, outsideColor: Color? = nil, height: CGFloat = 10)
struct RangeStrip               init(state: MetricState)
                                init(value: Double?, band: ClosedRange<Double>?, valueLabel: String, tint: Color = Theme.good)
struct TickRing<Center: View>   init(progress: Double, color: Color, size: CGFloat, ticks: Int = 48, animateOnAppear: Bool,
                                     accessibilityName: String? = nil, @ViewBuilder center: () -> Center)
                                init(progress:color:size:ticks:animateOnAppear:accessibilityName:)   // Center == EmptyView
enum   TickRingGate             static func firstOpenToday(_ key: String) -> Bool   // pass as animateOnAppear
struct StrainGauge              init(value: Double, target: ClosedRange<Double>, maxValue: Double = 21, height: CGFloat = 14)
struct Sparkline                init(values: [Double], color: Color = Theme.ink); static func monotonePath(_ p: [CGPoint]) -> Path
struct MetricRow                init(id: MetricID)                                   // v1, reads HealthStore from env, presents MetricSheet itself
                                init(state: MetricState, onTap: @escaping () -> Void) // v0.4
// v0.4 kept with the same initialisers: RingView(progress:color:track:lineWidth:delay:) → TickRing (no re-animate on appear),
// FlagPill(flag:color:) → StatusChip, RangeBar(value:band:flag:height:dotColor:) → BaselineRibbon.
```

### Behaviour notes
- **TickRing** draws its ticks with Canvas: 2×7 pt at 160 pt and scaled for other sizes. The ticks light up one at a time, 8 ms each, but only when `animateOnAppear` is true and Reduce Motion is off. Otherwise the ring is drawn already filled. A progress change steps tick by tick from the current count. Use `TickRingGate.firstOpenToday("recovery")` to get the "first open of the day" rule. The VoiceOver value is "N percent".
- **BaselineRibbon** has a paper track with a 0.5 hair stroke, an ink 10 % band and a 12 pt dot with a 2 pt card ring. The dot is ember inside the band. Outside the band it takes `statusTier.fill`, which is direction-aware: green when the value is better than usual, yellow/red when it is a concern.
- **RangeStrip** uses 4 pt dots on a 6.5 pt pitch. Dots inside the band ramp the tier colour from 30 to 100 % (left to right) and dots outside are hair. The current value is an ink dot with an ink pill label.
- **StrainGauge** fills a capsule ember → peach (mid stop from `Color.oklabMix`) with `printGrain(0.03)`, on a hair track. Two 2 pt ink ticks mark the target bounds.
- **PillPicker** has a card track with a hair stroke and an ink-filled selected segment with card-coloured text. Switching cross-fades with no slide and gives selection haptics.
- **FreshnessChip** updates every minute. After 3 h, or with no date, it turns into the limit chip with a clock glyph.
- **StatusChip** shows a 6 pt status dot plus the word in `label` style on a chip bg, radius 8.
- Everything has accessibility labels and values. MetricRow is one combined button with a hint.

### Deviations / open issues
- `MetricRow(id:)` opens `MetricSheet` with its own `.sheet` instead of through a `Route`, because `Route` has no metric case. D can add one later.
- `Flag` has no severity, so `StatusChip(flag:)` can only show In range or Watch. Use `StatusChip(state:)` to get Out of range (more than 1 SD past the band on the concern side).
- Fonts are rebuilt on each access because they are computed vars. They only rescale for Dynamic Type when the view re-renders.
- `Theme.heart`, `.activity` → ember and `.lungs` → graphite, because blue is removed. Panel tints are now low-key.
- Last build (build/A): the only error is ContentView.swift:37, a switch that is not exhaustive (not in my files).
