# Wave 1 · F · Live tab

Files: `MRH1/LiveView.swift` (rewritten from the stub) and `MRH1/LiveChart.swift` (new). No other files were touched.
Build (`build/F`): **BUILD SUCCEEDED**. My two files compile with 0 errors and 0 warnings, checked after touching them to force a recompile.

## What was built

### Header
- `OrbBackground(status: nil, evening:, pulse: live.pulse)` sits behind the header only, never behind a card.
- The evening palette is used from 20:00 to 05:00. In demo mode the time comes from the demo clock.
- Top bar: a 44 pt menu `RoundIconButton` that sets `nav.showMenu`, and "Live" as the title.
- "Heart rate" label. Next to it, the **"Bluetooth live"** badge appears only while `live.latestSource == .bluetooth`, and a "Sample data" chip appears in demo mode.
- **Big latest HR** in `Typo.display` with `.contentTransition(.numericText(value:))`. The "bpm" unit is baseline-aligned. It shows "—" when there is no reading.
- **SF Mono ticker** reads "Latest sample 42 s ago" / "Latest sample 7 min ago". It uses `TimelineView(.periodic(from: .now, by: 1))` and is always visible.
  - In demo mode it measures against `live.now`, so the pinned `-demoNow` clock stays consistent.
  - A yellow `FreshnessChip` appears next to it when the newest sample is more than 3 h old or there isn't one yet. Demo mode never shows it.
- Context line: "6 above your resting 56 bpm" (uses `health.state(.restingHR)`).

### Chart card
- **Title** states the takeaway, e.g. "Between 64 and 81 bpm this hour". For 7D/30D it says whether today's average is above, below or within your usual. The subtitle names the unit and what is drawn.
- **`PillPicker` Live·1H·24H·7D·30D** is bound to `live.selectedRange`. Switching ranges only crossfades: `.id(range)` + `.transition(.opacity)` + `Motion.crossfade`.
- **`LiveChart`** (Swift Charts):
  - Styled with `.mrhAxes()` plus a custom x axis in caption style (HH:mm, weekday, or day+month), with the y axis on the trailing side and a 3-line dotted hair grid.
  - Live/1H/24H: a 1.75 pt ink `LineMark` (`MRHChart.line`), `.monotone`, over an `AreaMark` filled with `.grainedArea(Theme.ember)`.
  - Gaps stay gaps. Each run of points gets its own `series` segment, and a gap of more than 6 min (Live), 4 min (1H) or 2.5 h (24H) breaks the line and the fill. A point left alone between two gaps gets a small ink dot.
  - Current point: B's `LivePointMark(pulse: live.pulse)`, a 6 pt ember dot with a card ring and a single ripple per new sample. Only Live and 1H ripple.
  - 24H: `RectangleMark` shading for the sleep window (`health.lastSleep`, falling back to `live.lastNight.window`), iris at 10 %. Today's workouts are shaded ember at 8 %. Both have micro labels instead of a legend.
  - 7D/30D: one round-capped min–max `RuleMark` capsule per day (graphite2), with an ink monotone average line.
    - Behind them is the **personal band**: your usual daily average, mean ± 1 SD (at least 2 bpm) over the 30D daily buckets excluding today, drawn in `Theme.bandFill`. It needs at least 5 days.
  - Y domain is padded and snapped to 10s. It never starts at 0.
  - Scrubbing: `chartXSelection` gives a 0.5 pt ink rule, an ink point and a card bubble ("72 bpm", time; or "68 bpm average", date and min–max). There is a `.sensoryFeedback(.selection)` haptic on each new point. It won't snap across a gap.
  - VoiceOver: `accessibilityChartDescriptor` (`LiveChartDescriptor`, Audio Graphs) with real values, plus a summary range.
- **Empty and waiting states:** a clock glyph plus "Waiting for sync" (no sample at all) or "No heart rate in this range yet", with a one-line batch explanation.
- **Min·avg·max strip:** "Lowest / Average / Highest" as `ValueText(.headline)` with bpm, value before label. Each cell is one VO element.

### So far today
Rows rather than tiles (competitors Decision 2). Each row has the name, a caption with context, the value, and a 28 pt **thin 300° arc** (3 pt, hair track).
- **Strain:** vs `Scores.strainTarget(health.recovery)`. The arc is ember with 2 ink ticks for the target band, and the caption gives the target range.
- **Stress now:** `today.stressNow` shows Calm/Medium/High in the status colour on the arc, with the word as the value. While moving it shows `Insights.movingWord`.
- **Steps:** progress vs your usual day (`state(.steps).baseline.mean`, falling back to 10,000), caption "640 in the last hour".
- **Active energy:** vs your usual (falling back to 500 kcal).
- Values come from `live.today` first, then fall back to `health.stepsToday` / `activeEnergyToday`. Missing values show `NotSentLabel(.waiting)`, never 0.
- At AX sizes, rows switch to a vertical layout.

### Last night
- Breathing rate and blood oxygen on a `BaselineRibbon`. It uses the `MetricState` ribbon, or `BaselineRibbon(value:band:)` when LiveStore's last-night value differs.
- Caption: "Your usual 13.2 – 15.1". Missing shows "Waiting for sync".

### Footer and lifecycle
- Footer: "Readings arrive in batches from Google Health. Fitbit Air has no blood-pressure sensor." plus "Wellness estimates, not medical advice."
- Pull to refresh runs `live.attach(health:)` and then `await live.refresh()`. It does not trigger the heavy `HealthStore.refresh()`.
- `.task { live.start(health:) }` (idempotent) and `.onChange(of: health.lastRefresh) { live.attach }`. The view therefore works whether or not D's shell also starts the store.

## Checklist (research/03 §9)
| # | Result | Note |
|---|---|---|
| 1 | Pass | The display HR is the only primary element. |
| 2 | Pass | Ink, ink2 and graphite. Semibold only on numerals and headlines. |
| 3 | Pass | Values come before labels in the stats strip and rows. |
| 4 | Pass | Section gap 32, inner gap 12–16, no card-in-card. Hairline dividers only inside the list cards. |
| 5 | Pass | At most 4 rows per card. |
| 6 | Pass | Typo roles only (UIFontMetrics). Smallest text is micro 11. |
| 7 | Pass | No light weights. |
| 8 | Pass | Typo roles are monospacedDigit, and the ticker is mono. |
| 9 | Pass | HR and bpm are baseline-aligned, with the unit in graphite (`unitStyle`). |
| 10 | Pass | Sentence case, no eyebrows. Mono is used only for the ticker, as the spec allows. Numbers use `.formatted()`. |
| 11 | Pass | Spacing uses `Space.*` tokens. Gutter 20, card padding 20. |
| 12 | Pass | Card 28. Bubble/chip 8 inside the chart (not nested in a padded shape). |
| 13 | Pass | Chart leading edge is inside the card padding, and the y labels are on the trailing side. |
| 14 | Pass | Menu 44 pt, PillPicker is A's (44 pt). |
| 15 | Pass | Rows reflow at AX sizes. The stats strip has 3 columns of headline text; tight at AX5 but values wrap rather than clip. |
| 16 | Pass | Ember marks only the current point, the fill, the strain arc and workout shading (as brand/focus). Status colours are used only for stress and the ribbon. No blue. |
| 17 | Pass | Stress shows a word, the ribbon has a VO direction text, and the stale chip has a clock glyph and words. |
| 18 | Pass | No ember, yellow or green small text. The chip uses limitText on limitBg. |
| 19 | Pass | Ink line on card. Grid (graphite2 dotted) < labels (graphite) < title (ink). |
| 20 | Pass | Text over orbs is ink/ink2. |
| 21 | Pass | Titles state the takeaway. The unit is in the subtitle, not on ticks. |
| 22 | Pass | 3 dotted hair lines, rounded ticks, default styling overridden. |
| 23 | Pass | Lines padded on a non-zero baseline. |
| 24 | Pass | One ink series, with context (bars, band, shading) in grey or tints. Direct labels, no legend. |
| 25 | Pass | Gaps are real segment breaks, "Waiting for sync" copy is used, and the ticker is always visible. |
| 26 | Pass | Scrub bubble and haptic. Min/avg/max are always visible. |
| 27 | Pass | No tab animation. Crossfade 200 ms, morph 300 ms. The ripple (1.1 s) is the spec's sanctioned Live moment. |
| 28 | Pass | One orchestrated moment: the new-sample pulse (orb +3 % and chart ripple fire together). |
| 29 | Partial | Reduce Motion is handled inside B's `OrbBackground` and `LivePulse`, and the numeric transition degrades to a fade. Increase Contrast and Bold Text have not been verified on device. |
| 30 | Pass | Combined VO elements with value, unit and context. Chart descriptor. Menu button labelled. No §8 tells found. |

## Deviations and open issues
- **Orb status is `nil` (neutral).** The Live screen has no single verdict, so I didn't borrow recovery from Today. This is easy to change if the orchestrator wants it.
- **Personal band for 7D/30D** is computed in the view from LiveStore's 30D daily averages. The spec wording is "daily resting HR inside the baseline band". LiveStore has no daily resting HR series, so the band shows your usual *daily average*. The caption says so.
- **`chartXSelection` inside a ScrollView:** a horizontal drag scrubs and a vertical swipe scrolls. This needs a real-device feel check.
- **Menu button:** I used `RoundIconButton` + `nav.showMenu`, because D's `MenuButton()` is not in the tree yet. Swap it in once it lands.
- **Shell wiring:** D's ContentView tab bar still needs to host `LiveView` in a NavigationStack. LiveView hides the nav bar itself.
- **Blood pressure** is covered by the footer line, not a "Not measured" row. The mock had a row, but that would be a permanent empty row.
- **Not visually verified yet:** `simctl install` hung on the shared booted simulator (other agents were using it), so I took no screenshot. The integrator should capture `-demo -tab live` in light and dark.
