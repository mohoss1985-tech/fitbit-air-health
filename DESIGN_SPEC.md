# MRH1 v1.0 — DESIGN SPEC (single source of truth)

Synthesised from research/01–08. **Where a research report disagrees with this file, this file wins.**
Every build agent runs the 30-item checklist in `research/03-ui-craft.md §9` on its screens before finishing.

## 0. Identity in one line
"Riso Paper instrument": warm printed paper, ink type, one ember signal, physiological charts
(baseline ribbon, dot-matrix range strips, tick rings, hypnogram) and a printed grain/halftone orb
header. Distinctiveness comes from subject-specific charts + disciplined type, NOT from decoration
(paper+terracotta is a known AI default — research/03 §8.12 — so the charts must carry the identity).

## 1. Conflicts resolved
| Topic | Decision |
|---|---|
| Ring numbers "SF Pro Light" (04) vs "no light weights" (01, 03) | **Semibold, rounded design, tabular.** No Light/Thin anywhere. |
| Mono axis labels (04) vs "monospace labels = AI tell" (03) | Axis/tick labels use `caption` (SF Pro, tabular). **SF Mono only** for the Live "latest sample N min ago" ticker and raw sample timestamps. |
| Gradient fills under charts (04) vs "fill under every chart = tell" (03) | Grained fill allowed **only** on the Live HR chart and the Strain-detail HR chart. All other line charts: line only. |
| Uppercase overline (01) vs "no tracked ALL-CAPS eyebrows" (03) | **No ALL-CAPS.** Section labels are `label` style, sentence case, graphite. |
| "danger" status wording (08 legal) | Tiers are **In range · Watch · Out of range** (green/yellow/red). No disease names, no clinical cut-offs. Drift alert copy: "2 signals are outside your usual range" — never "danger". |
| Middle-dot meta strings (03 tell) | Avoid chains like "A · B · C". One separator max per line. |
| Name | Keep **MRH1** in UI for now; never write "Fitbit" in the product name. "Works with Fitbit Air via Google Health" is allowed in body copy. Rename later (candidates in research/08). |

## 2. Tokens (Theme.swift / Typography.swift)
**Colour, light** — paper #EDEBE7 · card #FAF9F7 · ink #151413 · graphite #6B665F (text) · graphite2 #A8A39C (non-text: ticks, disabled, empty tracks) · hair #DFDBD5 · ember #F0582A (fills only) · emberInk #B83F17 (when ember must be text) · peach #F3A79E · iris #8B88F0 (sleep/night only).
Status: good #2F9D68 / bg #DDF0E4 / text #1F6E47 · limit #E6B820 / bg #FBF0C8 / text #7A5D05 · danger #D23A3A / bg #F8DCD8 / text #A92C2C. (chip text darkened to pass 4.5:1). Yellow/ember/green/iris are **never small text**.
**Dark / evening** (respect system appearance; remove forced dark): base #151413, card #1F1D1B, ink #F2EFEA, ink2 #B4AEA7, ink3 #8A847D (≥13 pt only), hair #2E2B28; status fills same hue, chips use 18% alpha bg + light text.
**No blue anywhere.** v0.4 blue roles: "Low" flag → limit (yellow) with direction word; strain → ember; light sleep → peach-graphite #C9B8A6; REM → iris; deep → ink-iris #4B4880; awake → danger at 60%; "Moving" stress bars → graphite2.
Keep v0.4 Theme names as aliases (recovery→good, warn→limit, bad→danger, low→limit, strain→ember, sleep→iris, etc.).

**Type** (9 roles only, Dynamic Type via `relativeTo:`): display 56 semibold rounded −0.04em · title 28/34 semibold −0.02em · metric 34 semibold rounded −0.03em · headline 17 semibold · body 15 regular · label 13 medium · caption 12 regular · micro 11 medium (minimum size anywhere) · mono 12 medium SF Mono (Live ticker only). All numerals `.monospacedDigit()`. Unit = caption, graphite, 2 pt gap, baseline-aligned. Missing value = "—" + NotSent caption.

**Spacing**: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 only. Gutter 20, card padding 20, card gap 12, section gap 32.
**Radii**: card 28 · inner 16 · chip 8 · capsule. Chart bars 2 pt top radius. Nothing else.
**Depth**: cards = fill only (no border, no shadow, light). Frosted round icon buttons 44 pt: `.ultraThinMaterial` + 0.5 pt hair stroke + 2-layer shadow (ink 4% y1 r2, ink 6% y8 r24).
**Icons**: SF Symbols, one weight (.medium in buttons, .regular inline). No tinted icon circles, no emoji.

## 3. Signature graphics (Metal, iOS 17 `ShaderLibrary` + `.colorEffect/.layerEffect`)
Spec = research/04 "Gradient spec" + research/06. Summary: 3 orbs (ember, peach, iris) at the header only (Today + Live, never behind cards), **solid inner 70% radius, smoothstep edge 70→100%**, OKLab premultiplied mixing, static per-pixel grain ±4% L scaled by coverage, halftone dot fringe (3 pt pitch, 15°) in coverage 0.12–0.40, triangular dither ±0.5/255. Status adds a 4th small orb (good/limit/danger tint at 0.5). Drift Lissajous 41/53/67 s amplitude 0.05w; state change morph 1.2 s; Live: ember radius +3% on new sample, 500 ms decay. Evening: ink base, orbs 0.55. Reduce Motion: frozen. Pause when off-screen; cap 30 fps via TimelineView(.animation(minimumInterval: 1/30)).

Charts (research/04 "Chart spec"): 1.75 pt line, round caps, monotone interpolation, gaps stay gaps; gridlines horizontal, hair 0.5 pt dotted (1 on/3 off), max 3; current point 6 pt ember + 2 pt card ring, single ripple on new sample (Live only); dark mode only: 6 pt blur glow at 22%. Override ALL default Swift Charts styling (no blue, no default axes).
- **Baseline ribbon** (brand shape): paper track, personal normal = ink 10% band, today = ember dot that turns status colour only when outside band (direction-aware via `Insights.direction`). Used in every metric row, sheets, Live 7D/30D.
- **Dot-matrix range strip** for vitals in Body + MetricSheet (4 pt dots, 6.5 pt pitch).
- **Tick rings**: 48 ticks 2×7 pt, result colour vs hair, sequential light-up 8 ms/tick only on first open of the day.
- **Strain capsule gauge**: ember→peach OKLab fill + grain, target zone = 2 ink ticks.
- Stress/steps bars: 3 pt gap, status colours; future slots hair outline.

## 4. Information architecture
Tabs (round icons, ink-filled selected, no animation on switch): **Today · Live · Body · Trends**.
Top-left round button = **menu** (Results guide, Data sources, Notifications toggles, About + disclaimer). Top-right on Today = **+** journal.
**Today** (above the fold, iPhone 18 Pro): date + day circles week strip → verdict sentence (time-of-day aware: morning recovery verdict / afternoon strain vs target / evening wind-down) over orbs → Recovery hero tick ring with Sleep + Strain smaller rings → freshness chip "Synced 23 min ago" (yellow after 3 h) → "3 of 4 signals" footnote when HRV missing. Below: strain target capsule + advice → stress 24 h bars → panels strip (4 capsules, "N to watch") → drift banner → health-monitor heat map → last night (StageBar) → sleep debt + consistency → week day cards → weekly report (Mondays) → journal discoveries.
**Live**: see research/05 + GOAL §3. Header orbs + big latest HR (display) + SF Mono "latest sample 4 min ago" (TimelineView 1 s) → segmented Live·1H·24H·7D·30D (black pill) → chart with min·avg·max strip (24H shades sleep, 7D/30D show baseline ribbon band) → "So far today": strain vs target, stress now, steps, active energy (thin arcs) → "Last night": breathing + SpO2 on baseline ribbons → footer "Readings arrive in batches from Google Health. Fitbit Air has no blood-pressure sensor." No promise of real-time.
**Body**: segmented Heart · Lungs · Sleep · Activity; each metric row = label · value+unit · flag chip · ribbon · 7-day sparkline → MetricSheet.
**Trends**: Apple Trends grammar (sentence, grey bars, old-avg vs new-avg lines), changed trends first, "All metrics" for the rest; weekly report; body age.
Score details (sheets/push): contributors as weighted bars either side of "your normal" with weight shown, 14-day chart, "How it's computed".

## 5. Copy rules
Second person, calm, ≤14 words per insight: change + vs your baseline + one action. No exclamation marks, no emoji, sentence case, curly quotes, "…". Three missing states: "Not sent by Google Health" (HRV, skin temp, VO2 max) · "Waiting for sync" · "No reading". Early baseline: "Early read: 6 of 14 baseline days." English only (fix "Apple Santé", remove hard-coded "Mo."). Footer everywhere relevant: "Wellness estimates, not medical advice."

## 6. Motion (Motion.swift)
press 0.97 / 160 ms easeOut · enter cubic(0.23,1,0.32,1) 220 ms from 0.96+opacity · morph cubic(0.77,0,0.175,1) 300 ms · sheets system · numbers `.contentTransition(.numericText())` · range switch = crossfade only · no tab animation · no per-card stagger · Reduce Motion → opacity only.

## 7. Demo mode
research/07 §5: `-demo` launch arg or Simulator by default; deterministic port of web/demo/data.js through the real pipeline; Live appends a sample every 5 s; "Sample data" chip in header; screenshot args `-tab`, `-open`, `-uiLight/-uiDark`.

## 8. Shared API contract (names are FIXED — owners implement, everyone else codes against them)
**Theme (agent A, Theme.swift)** — `enum Theme` static `Color`s, adaptive light/dark via `Color(light:dark:)`:
`paper, card, ink, graphite, graphite2, hair, ember, emberInk, peach, iris, good, goodBg, goodText, limit, limitBg, limitText, danger, dangerBg, dangerText, stageDeep, stageCore, stageREM, stageAwake` + all v0.4 names kept as aliases. `Flag.chipColors -> (bg: Color, text: Color)` may be added by A in Theme.swift as an extension.
**Typography (A, Typography.swift)** — `enum Typo` static `Font`s: `display, title, metric, headline, body, label, caption, micro, mono`; `View.unitStyle()`; `ValueText(value: String, unit: String, size: .display|.metric|.headline)` baseline-aligned.
**Spacing/Radius (A, Theme.swift)** — `enum Space { xs=4, s=8, m=12, l=16, gutter=20, xl=24, section=32, xxl=48 }` (CGFloat), `enum Radius { card=28, inner=16, chip=8 }`.
**Motion (A, Motion.swift)** — `Motion.press, .enter, .morph` (Animation), `PressStyle: ButtonStyle`, `View.motionSafe(_ anim:)` respecting Reduce Motion.
**Components (A, Components.swift)** — `Card<Content>(padding:)`, `SectionLabel(_ text:)`, `PillPicker<T: Hashable>(selection:options:label:)` (black pill segmented), `RoundIconButton(systemName:label:action:)` (44 pt frosted), `StatusChip(flag: Flag)` (word + colour: In range/Watch/Out of range), `NotSentLabel(kind: .notSent|.waiting|.noReading)`, `FreshnessChip(date: Date?)`, `BaselineRibbon(state: MetricState)`, `RangeStrip(state: MetricState)` (dot-matrix), `TickRing(progress: Double, color: Color, size: CGFloat, ticks: Int = 48, animateOnAppear: Bool)`, `StrainGauge(value: Double, target: ClosedRange<Double>)`, `Sparkline(values:)`, `MetricRow(id: MetricID)` (label · value · chip · ribbon · sparkline, taps open MetricSheet via Route). Keep v0.4 `RingView`, `FlagPill`, `RangeBar`, `Card`, `MetricRow` working (wrap or alias) until other files migrate.
**Graphics (B, OrbBackground.swift, Shaders.metal, OKLab.swift, ChartStyle.swift)** — `OrbBackground(status: Flag?, evening: Bool, pulse: Int = 0)` (pulse increments trigger the +3% ember bump), `View.printGrain(amount: Double)` (static grain overlay via layerEffect for chart fills/bars), `GrainedAreaFill(color:)` ShapeStyle-ish view helper, `ChartStyle` view modifiers: `.mrhAxes()`, `.mrhGrid()` for Swift Charts, `LivePointMark`/ripple helper, `Color.oklabMix(_:_:t:)`.
**Data (C)** — `HealthStore` (existing API + `activeEnergyToday`, 14-day `history`), `LiveStore` per research/07 §4 contract + `pulse: Int` (increments on each new sample), `Demo.isOn`, `Journal` (`JournalStore` @Observable: `tags`, `entries(for:)`, `toggle(tag:on:)`, `discoveries: [String]`), `Settings` (@AppStorage keys).
**Routes (D, Routes.swift)** — existing `Route` enum; add cases `.live, .menu, .journal, .dataSources, .guide` only if needed; D owns it.

## 9. Parallel build rules
- Edit ONLY files you own (research/07 §6 table). Need something from another owner's file? Code against the contract above; if truly missing, add a small `private` helper in your own file instead.
- Build with your own derived data path to avoid clashes: `-derivedDataPath build/<agentletter>` and `dangerouslyDisableSandbox: true`. Other agents are editing concurrently, so errors in files you don't own are expected mid-way: retry after a minute; only fix errors in your files.
- Finish only when your files compile and you've run checklist research/03 §9 on your screens. Write `research/wave1-<letter>.md` (what you built, deviations, open issues).
