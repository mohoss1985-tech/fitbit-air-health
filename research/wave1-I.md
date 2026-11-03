# Wave 1 · I — Score details + sheets

Files: `MRH1/ScoreDetailView.swift`, `MRH1/MetricSheet.swift`, `MRH1/ExplainSheet.swift`, `MRH1/SleepGraphics.swift`.
Build (`build/I`): **BUILD SUCCEEDED**, with 0 errors and 0 warnings in my files. I built against A's, B's and C's finished APIs.

## Built
**ScoreDetailView** (paper page, gutter 20, cards 28/20, inline nav title, disclaimer footer)
- *Shared header card:* a 132 pt `TickRing` with `ValueText` in the centre, a status chip (Recovery only), a verdict headline, a body caption and an optional footnote. At accessibility sizes it switches to a VStack (`AnyLayout`). It doesn't re-run the tick animation; that plays only on Today's first open.
- *Recovery:*
  - **Header:** `Scores.verdict`, a chip from the score tier (67 / 34), and the footnote "3 of 4 signals. HRV is left out." from `RecoveryResult.signalsText` / `missingInputs`.
  - **"What drove it":** a "Worse · Your normal · Better" axis label, then one diverging bar per contributor (paper track with a 1 pt ink centre tick). Length = |z|/3. Thickness scales with the input's re-normalised weight. Colour: good for better, limit for worse, danger when z ≤ −2. Each row has a caption ("1.2 SD better than usual" / "Weight 42 %"). Missing inputs show as grey rows: "Not sent by Google Health. Left out, the rest re-weighted." Each row opens `MetricSheet`.
  - **"Last 14 days":** from `health.history`. The line is ink 1.75 monotone, and missing days split it into separate runs so gaps stay gaps. Points use the tier colour, and the last point is ember with a card ring. Fixed 0–100 scale with a 0/50/100 dotted grid, and the x axis shows only the first date and "Today". Drag-select shows a bubble with a haptic.
  - **Other states:** the calibrating checklist (4 inputs: Ready / N of 4 nights / Not sent / Waiting for sync, 44 pt rows), and an expandable "How it's computed" card (z-score, the weights table, re-weighting, the curve, tier cut-offs, the 8 h sleep need, 3 to 14 baseline nights).
- *Strain:*
  - **Header:** ring out of 21 in ember, plus target-aware advice.
  - **"Today's target" card:** `StrainGauge` with the `Scores.strainTarget` band.
  - **HR-today chart:** an `AreaMark` with `.grainedArea(Theme.ember)` plus an ember line. Runs split at gaps over 15 min. Takeaway subtitle is "Peak N bpm at HH:MM". Scrubbing uses a binary-search nearest point, a bubble and a haptic per 5-min step. It shows "Waiting for sync" when there's no data.
  - **Zones and workouts:** 5 zone bars (OKLab peach→ember ramp, 2 pt radius, print grain, "Zone N / 50–60 %" labels, total-minutes takeaway) and a workouts list.
- *Sleep:*
  - **Header:** score ring in iris, "7 h 48 asleep", times plus efficiency. When the night is stale the footnote reads "Waiting for sync".
  - **Hypnogram card:** takeaway sentence (deep + REM share), the hypnogram, and `StageTotals`, a direct-labelled legend with swatch, minutes and %. Nights without stages fall back to `StageBar`.
  - **Metric rows:** 4 `MetricRow(id:)` with hair dividers. The not-synced state is kept.

**SleepGraphics**
- **`StageBar(session:)`:** unchanged init. Order is deep→light→REM→awake, with 2 pt gaps, radius 2 and an accessibility value.
- **`Hypnogram(session:, showsLabels: true)`:** Canvas. Direct row labels (Awake/REM/Light/Deep), dotted hair row guides, graphite2 hairline risers joining stages, and a start/end time axis. Colours come only from Theme stage tokens; there is no blue.
- **Additions:** `SleepStage.shortLabel / hypnoRow / barOrder` and `StageTotals`.

**MetricSheet(state:)** (init unchanged, so A's `MetricRow(id:)` presents it as before)
- **Header:** title, sub, a metric `ValueText` and `StatusChip(state:)`. Instead of the chip, a Waiting chip shows when the value is old, and a "—" + NotSent label shows when there's no data.
- **Range:** `RangeStrip(state:)` with a caption: the direction sentence plus the early-read and last-reading notes.
- **Tiles:** "Your range" vs "Typical adult", then the what text, then "If higher" / "If lower" (arrow glyphs, no colour coding). They wrap to a VStack via `ViewThatFits`.
- **Trend:** `PillPicker` Week/Month and a takeaway subtitle ("Average 58 bpm this week, 2 outside the band."). Chart layers:
  - `RectangleMark` personal band (ink 10 %)
  - ink line split at gaps
  - points with card rings, coloured direction-aware: good inside the band or on the better side, limit or danger on the concern side
  - `RuleMark` with bubble and selection haptic
  - Week shows narrow weekday labels and Month shows weekly date labels
  - B's `.mrhAxes()` y grid
  - a direct band caption
- **Three missing states:** Not sent / no reading (no data), Waiting for sync (value older than today), and "trend appears after a few days".
- **Disclaimer:** `SheetDisclaimer`.

**ExplainSheet** (same init): title/sub/what, plus a paper inner tile of label/text rows with hair dividers that stack at accessibility sizes, then the disclaimer. I added a shared `SheetDisclaimer`: "Wellness estimates, not medical advice. Readings come from a wrist sensor, not a medical test." It keeps the v0.4 line.

New shared types (internal): `ChartBubble`, `SheetDisclaimer`, `StageTotals`.

## Deviations
- **Recovery weights:** `Scores.swift` doesn't expose them, so a private `RecoveryWeights` in ScoreDetailView mirrors them (0.40 / 0.25 / 0.20 / 0.15). The shown weight is each input's share after re-weighting. **C:** consider exposing `Scores.recoveryWeights` so the two can't drift apart.
- **Recovery tier mapping:** 67+ is In range, 34–66 Watch and under 34 Out of range, matching `recoveryColor`.
- **Bubble styling:** the scrub bubble uses a hair stroke and no shadow, because the spec says cards have no shadow.
- **v0.4 copy:** "Right of the line = better" became the sentence "Right of the line helped your score, left of it pulled it down." The v1 mock shows the opposite side, but I kept v0.4's semantics.

## Checklist (research/03 §9) on Recovery / Strain / Sleep / MetricSheet / ExplainSheet
Pass:
- **Hierarchy (1–5):** the ring number is the primary element. Value comes before label, there's no card-in-card (inner tiles are paper on a sheet), and each group has 7 or fewer rows.
- **Type (6–10):** Typo roles only, 11 pt minimum, no Light weights, tabular digits, `ValueText` baseline units, sentence case, no mono, and NBSP before % and units.
- **Layout (11–14):** spacing tokens only, gutter 20, radii 28 / 16 / 8 / 2, and charts inside the card padding. Tap targets are full-row buttons, and the header toggle is 44 pt.
- **Layout (15):** headers, explain rows and tiles all reflow at accessibility sizes.
- **Colour (16–20):** ember only for strain and the "now" point, status colours only for status, and always with words (SD better/worse, tier words). No blue. Text uses ink and graphite only.
- **Charts (21–26):** takeaway subtitles with units, 3 dotted gridlines, 0–100 fixed for scores, padded line domains, one ink series, direct labels instead of legends, gaps kept, "Not sent" / "Waiting" never 0, and scrub bubbles with haptics.
- **Motion and a11y (27–30):** crossfade on range switch, `Motion.morph` on the expander, no tick animation in the detail view, Reduce Motion honoured via A's `Motion.animate` / `TickRing`. Combined accessibility elements with value, unit and status. Charts have labels and values.

Open:
- **#29, #18 (dark mode / Increase Contrast):** not visually verified. I couldn't screenshot because the shared simulator was on onboarding with a notification prompt. I didn't take it over from other agents.
- **#26:** the 900-point HR chart scrub hasn't been performance-tested on a device.

## Open issues
- Today doesn't currently call `StageBar` (grep finds no caller). The owner of the Today "Last night" card should use `StageBar(session:)`, with a height of 10–12 pt.
- `history` days with no recovery leave gaps. If `history` is empty the card says so and draws no fake zeros.
