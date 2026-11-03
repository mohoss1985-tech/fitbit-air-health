# Wave 1 · B — Graphics (Metal + chart styling)

Owner files: `MRH1/Shaders.metal` (new), `MRH1/OKLab.swift` (new), `MRH1/ShaderViews.swift` (new),
`MRH1/OrbBackground.swift`, `MRH1/ChartStyle.swift`. Build status: **BUILD SUCCEEDED**
for the whole project (build/B, 2026-11-03). There are no warnings in my files.

## API (DESIGN_SPEC §8 names kept exactly)

| Name | Where | Notes |
|---|---|---|
| `OrbBackground(tier: StatusTier?, evening: Bool, pulse: Int = 0)` | OrbBackground.swift | **Preferred for Today** (pass Recovery's tier). inRange → green, watch → yellow, outOfRange → **red**, nil → no status orb. |
| `OrbBackground(status: Flag?, evening: Bool, pulse: Int = 0)` | OrbBackground.swift | Contract init, unchanged. Header orbs. Give it any height, e.g. `.frame(height: 420).ignoresSafeArea(edges: .top)`. It fades to the page base by `min(1·width, height)`. |
| `View.mrhAxes(xCount: 4, yCount: 3)` | ChartStyle.swift | x labels plus trailing y labels in `Typo.caption.monospacedDigit()` and graphite. Dotted grid (0.5 pt, 1 on / 3 off), no ticks, `.tint(Theme.ink)`. |
| `View.mrhGrid(lines: 3)` | ChartStyle.swift | Dotted grid only; axes hidden. Use it **instead of** `mrhAxes`, not with it, because the innermost axis modifier wins. |
| `View.printGrain(amount: Double)` | ChartStyle.swift | Static per-device-pixel OKLab grain (`colorEffect`, reseeds daily). It also varies ink density on translucent pixels. Put it on shapes and bars, not on text. 0.03 is typical. |
| `GrainedAreaFill(color: = Theme.ink, top: nil)` | ChartStyle.swift | A view that fills its frame, fading to 0 at the bottom, plus grain. The default top alpha is **ink at 12 %**; any other series colour gets 24 %. |
| `.foregroundStyle(.grainedArea())` / `.grainedArea(Theme.ember)` | ChartStyle.swift | The same fill as a `Shader` ShapeStyle. **This works directly on Swift Charts `AreaMark`** (verified in render). |
| `LivePointMark(x:y:pulse:color:)` | ChartStyle.swift | ChartContent: a `PointMark` whose symbol is `LivePulse`. |
| `Color.oklabMix(_:_:t:)` | OKLab.swift | Stays adaptive: it resolves light/dark per trait through a dynamic `UIColor`. |
| `MRHChart.line / .grid / .gridCount / .barGap / .barRadius` | ChartStyle.swift | Shared stroke constants (1.75 pt round line). |
| `GlowLine(values:domain:color:lineWidth:fill:)` | ShaderViews.swift | SDF line. Gaps stay gaps. It defaults to **ink**; use ember only for Strain. `fill: true` adds the grained fill (Live HR and Strain HR only; ink 12 % / colour 24 %). The 6 pt / 22 % glow is automatic in dark mode only. |
| `LivePulse(pulse:color:diameter: 6)` | ShaderViews.swift | Dot with a 2 pt card ring. Each `pulse` change fires **one** ripple (1 → 2.4, 0.35 → 0, 1.1 s). Static under Reduce Motion. |
| `Hairline(axis:color:)`, `PixelSnap`, `.mrhGlowUnderlay(GlowLine)` | ShaderViews.swift | 1-device-pixel lines, and a GlowLine placed inside a Chart's plot frame. |
| `OKLab`, `GfxTokens` | OKLab.swift | OKLab maths, `.arg` for shaders, `OKLab.stops(...)` for OKLab-sampled gradients (e.g. the strain capsule ember → peach). |

Shaders: `mrhOrbs`, `mrhGrain`, `mrhGrainedArea` (ShapeStyle), `mrhChartLine`. I dropped the draft's `mrhRingGlow` because tick rings are agent A's and the spec has no glow ring.

## What changed vs the draft (the fix for "too blurry")
- **Layout** (research/04, revised after coordinator review): peach (0.12, −0.02) r 0.60 · ember **(0.96, −0.06) r 0.40**, moved up and right so the verdict headline sits mostly on peach · iris (0.52, −0.10) r 0.24 at 0.35 · status orb **(0.60, 0.40) r 0.18** at 0.5. The status orb is now drawn *first*, so the peach and ember fringes print over it. It sits inside the cluster and within the header band (bottom edge about 0.58 w ≈ 26 % of screen height), with no OKLab mud from mixing green over peach.
- **Edge**: solid core to 0.70 r, then a smoothstep to r. In the fringe (coverage below about 0.4) the fade is replaced by a **halftone dot screen** (3 pt pitch, 15°, dot area = tone, 1-device-pixel antialiasing) that runs to 1.12 r. This is the printed edge from refs 03 and 08.
- **Grain**: static, per device pixel, triangular, ±4 % L scaled by coverage (±1 % on bare paper, ±3 % in dark). Then a ±0.5 LSB triangular dither before output.
- **Motion**: Lissajous drift with amplitude 0.05 w and periods 41/53/67 s. Status changes morph in OKLab over 1.2 s. Each `pulse` change gives ember +3 % radius, decaying over 500 ms with an ease-out.
- **Lifecycle**: `TimelineView(.animation(minimumInterval: 1/30, paused:))`. It pauses under Reduce Motion (frozen frame at t = 9; the pulse and morph snap), off-screen (`onGeometryChange` maxY ≤ 0), on disappear, and when `scenePhase == .background`.

## Deviations / decisions
- **Dark vs evening.** The dark variant follows the system `colorScheme`: ink base #151413, grain ±3 %. Orbs are trimmed below spec to **ember 0.48 · peach 0.34 · iris 0.22** (spec: 0.55, iris 0.6), because at the spec values light ink text over the orbs measured only 3.2:1. `evening: true` in light mode gives a dusk palette on paper (iris 0.6, ember 0.85, peach 0.8) instead of forcing an ink header, so there is no forced dark. If you want `evening` to force ink, change one line in `OrbBackground.shader(at:)`.
- **Flag mapping** (old init): `.normal` → green, `.high`/`.low` → yellow, `.none` or `nil` → none. Red is reachable through `init(tier:)`.
- **Contrast** (measured on text-free renders across the header band, top 34 % of the screen, every pixel): light good/watch **5.22:1** minimum, evening **5.97:1**, dark good **4.84:1**, dark watch **4.61:1**. All are ≥ 4.5:1 against Theme.ink (light #151413 / dark #F2EFEA).
- **Grain uses `colorEffect`, not `layerEffect`.** It is cheaper and needs no sampling.
- **Ink-density grain.** The grain on fills modulates alpha by ±65 % × noise, as well as ±3 % L. At ±35 % the fill grain could not be seen at 3×.
- **`.grainedArea` scale.** The ShapeStyle form takes `scale` (default 3), because a static ShapeStyle cannot read `displayScale`. `GrainedAreaFill` passes the real value.

## Visual verification
I compiled a harness (`research/wave1-B-renders/harness-main.swift.txt`) against my files, Theme and Typography, with `Shaders.metal` built into `default.metallib`. I ran it in the iPhone 18 Pro simulator with `simctl spawn`, rendered through `ImageRenderer` at 3×, and iterated twice: moved the status orb, narrowed the fringe, and strengthened the fill grain.
Renders (1206×2622, long headline wraps the same way it will on device): `research/wave1-B-renders/orb-light-good.png`, `orb-light-watch.png`,
`orb-light-danger.png`, `orb-light-evening.png`, `orb-dark.png`, `orb-dark-danger.png`; text-free `bare-*.png` (used for the contrast measurement); crops `crop-head.png` (header detail) and `crop-fill.png` (ink line with grained ink fill). The sample chart uses an ink line, an ink 12 % grained fill and an ember current point; the second chart is a Strain-style ember GlowLine.
Result: the orbs read as printed discs with grain and a dot-screen edge. Lines are crisp at 3× with 1-device-pixel edges. The grained `AreaMark` works, the dotted grid uses caption labels, and the grained status bars and the OKLab ember → peach capsule render cleanly. The dark-mode glow shows on GlowLine and LivePulse.

## Open issues
- No in-app screenshot yet. The app builds now, but Today and Live (other agents) still need to place `OrbBackground` in the header (Today: `OrbBackground(tier:evening:)`).
- At 0.5 alpha on paper, the red status orb reads as coral. If it should read more clearly as "Out of range", raise the danger alpha in `StatusTint.alpha`.
- The ripple inside a Swift Charts symbol (`LivePointMark`) may lose its `@State` if Charts rebuilds the symbol view. If the ripple doesn't show in Live, overlay `LivePulse` at the point's position instead (`ChartProxy.position(for:)`).
- Web (`web/demo/orbs.js`) is not done in this wave. The GLSL port should mirror `mrhOrbs`.
