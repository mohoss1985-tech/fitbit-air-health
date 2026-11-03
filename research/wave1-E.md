# Wave 1 — Agent E: Today tab + JournalSheet

Files: `MRH1/TodayView.swift`, `MRH1/TodayCards.swift`, `MRH1/TodayWeek.swift`, `MRH1/JournalSheet.swift`.
Build (`build/E`): **BUILD SUCCEEDED**, 0 errors and 0 warnings in my files. Code is reconciled with the final APIs in wave1-A and wave1-C plus D's `AppNav`.
Not yet checked in the Simulator (no screenshots taken). The integrator should look at the `-demo -tab today` screenshots, light and dark.

## What Today contains (DESIGN_SPEC §4 order)
1. **Header (the only place with orbs).** `OrbBackground(status:evening:)` sits behind the header, masked to fade into paper and extended under the status bar. The nav bar is hidden.
   - Top bar: `RoundIconButton` menu (`nav.showMenu = true`), then the greeting from `health.greeting(at: Demo.now)` (headline) with the date (caption), then a `+` button (`nav.showJournal = true`). D presents `MenuView` and `JournalSheet` at the root.
2. **Day circles.** Each of the last 7 days has a recovery ring in its tier colour on a hair track, the weekday letter, and the date. Today is filled with ink. Tapping a circle selects that day's card in Your week and scrolls there.
3. **Verdict sentence.** `title` style, ink, 14 words or fewer, and it changes with the time of day:
   - Morning: a recovery verdict with the strain target.
   - 12–18: strain so far against the target.
   - Evening: wind down, with a bedtime target worked out from the average wake time of the last 3 nights, minus 8 h of need, minus up to 30 min for sleep debt, minus 15 min to fall asleep.
4. **Rings in Whoop order: Sleep · Recovery · Strain.**
   - Recovery is the hero: a `TickRing` at 172 pt with the `display` number and %.
   - Sleep (iris) and Strain (ember) are 76 pt rings with 36 ticks.
   - Tapping any ring opens `Route.score(...)`.
   - Ticks animate only on the first open of the day (`TickRingGate.firstOpenToday("today.rings")`).
   - At accessibility text sizes the layout stacks: the hero on top, the two small rings below.
5. **Status lines.**
   - Recovery `StatusChip(tier:)`, `FreshnessChip(date: health.latestSampleDate)`, and a "Sample data" chip when `Demo.isOn`.
   - The `signalsText` footnote ("3 of 4 signals. HRV is not sent by Google Health.").
   - The v0.4 stale-sleep explanation with a clock glyph, kept as a caption.
6. **Strain target card.** `StrainGauge`, a "6.2 of 14–17" header, a 0/21 scale, and the v0.4 advice text.
7. **Stress card.**
   - One takeaway sentence, then 24 hourly bars (3 pt gap, 2 pt top radius, `printGrain(0.03)`) in status colours.
   - "Moving" hours are graphite2. Future hours are hair outlines. Past hours with no reading are a 1 pt hair line (a gap, never a zero).
   - Hour axis, a legend with words, the last synced hour, and the ⓘ ExplainSheet.
8. **Panels strip.** 4 capsules showing each panel's worst `statusTier`, with "N to watch" or "All in range". Tapping it switches to the Body tab (`nav.tab = .body`).
9. **Drift banner.** Shown for 2 or more vitals. The copy is softened: "2 signals are outside your usual range", followed by the names, then "Your body may need more rest. Consider an easy day." Ink text on limitBg, radius 28. Never "danger", no ALL-CAPS.
10. **Health monitor heat map.** 5 vitals × 7 nights.
    - Cells: In range is green at 75 %. Watch and Out of range are direction-aware and use the same >1 SD rule as A.
    - **Not sent** is a filled hair cell, and the row label carries a "Not sent" caption. **No reading** is a hair outline.
    - Tapping a row name opens `MetricSheet`. The legend is `Insights.heatMapLegend` plus a note on what Not sent means.
11. **Last night card.** Times, `ValueText` asleep, `StageBar`, and minutes per stage with direct labels (Deep/Core/REM/Awake). Shows a "Waiting for sync" label when the night is stale. Tapping it opens Sleep detail.
12. **Your week** (`SectionLabel`).
    - A sleep debt and consistency card: two tiles split by a hairline. Each has a value, a status dot with a word, a subtitle, and opens its ExplainSheet.
    - Swipeable day cards (`WeekStrip(selected:)`) with a `TickRing` for recovery, plus sleep, strain and steps. One headline sentence on top.
13. **Weekly report on Mondays.** `WeeklyReportCard()`, owned by H.
14. **Journal / Discoveries card.**
    - Shows `journal.discoveries` when there are any, with the note "Patterns in your own data, not causes."
    - Otherwise shows `progressText`.
    - Lists today's tags and has a "Tag today" button.
15. **Footer.** "Updated HH:MM. Pull down to refresh." and "Wellness estimates, not medical advice." Pull to refresh is kept.

**JournalSheet**
- Title "What shaped your day?" and a `PillPicker` for Today / Yesterday.
- Tags are text chips only, no emoji, laid out in a wrapping flow. Selected = ink fill with paper text. Unselected = card fill. Radius 8, at least 44 pt tall.
- Toggling uses `journal.toggle(tag:on:date:)` and gives selection haptics.
- You can add a custom tag (`addTag`). Footer: "Tags stay on this iPhone."

## v0.4 features kept (audit §3 rows 3–15)
| Row | Feature | Status |
|---|---|---|
| 3 | Greeting and verdict header | kept; no name ("Mo." removed) |
| 4 | 3 rings → detail | kept |
| 5 | Stale-sync explanation | kept |
| 6 | Weekly report on Mondays | kept |
| 7 | Strain target and advice | kept |
| 8 | Stress chart, legend, Moving, last sync, ⓘ | kept |
| 9 | Panels strip | kept |
| 10 | Drift banner | kept, softened |
| 11 | Health monitor → MetricSheet | kept |
| 12 | Last night → Sleep detail | kept |
| 13 | Debt and consistency with ExplainSheets | kept |
| 14 | Week cards | kept, plus day circles |
| 15 | "Updated", pull to refresh | kept |

Row 16 (Data sources toolbar button) moved to D's menu.

## Deviations
- **`evening`.** It is passed from the time of day (18:00–04:00). B's shader takes the ink base from the colour scheme, so in light mode, evening only shifts the palette to dusk.
- **Orb status.** `OrbBackground` takes a `Flag`, which has no danger level, so recovery below 67 maps to `.high` and the orbs show yellow, not red.
- **Day cards.** The selected card gets a 1 pt ink outline. The v0.4 scale-on-scroll effect is gone, per the motion rules.
- **JournalSheet** wraps itself in its own `NavigationStack` for the Done button. ContentView's `Route.journal` push would nest stacks. That route is unused, since D presents it as a sheet, but it would be cleaner if it set `nav.showJournal`.

## 30-item checklist (code review; visual confirmation pending screenshots)
| # | Result | Notes |
|---|---|---|
| 1 | Pass | One primary element: the 172 pt recovery ring with the display number. |
| 2 | Pass | Colours: ink, ink2 and graphite. Weights: semibold (headline/title/numbers) and regular/medium. |
| 3 | Pass | Values come before labels in rings and tiles. |
| 4 | Pass | Card gap 12, section gap 32. No card-in-card: the sleep tiles share one card with a hairline. |
| 5 | Pass | At most 7 per group (day circles, heat-map columns). |
| 6 | Pass | Only `.typo` roles, smallest is micro 11. Icons use text styles. |
| 7 | Pass | No light or thin weights. |
| 8 | Pass | Typo roles carry `monospacedDigit` (A). |
| 9 | Pass | Hero and metrics use `ValueText`, baseline-aligned. |
| 10 | Pass | Sentence case and no tracked caps. Middle dots only inside ExplainSheet row keys (v0.4 copy). |
| 11 | Pass | Only Space tokens. The 5 pt / 0.5 pt / 2.5 pt values are stroke and inset sizes, not spacing. |
| 12 | Pass | Card 28. Inner field 16. Chips 8. |
| 13 | Pass | Everything sits on the 20 pt gutter or card padding. The week scroller uses `scrollClipDisabled` and stays inside. |
| 14 | Pass | Icon buttons 44. Day circles, chips, ⓘ, heat-map rows and the journal button are all at least 44 pt tall. |
| 15 | Pass* | Rings stack at AX sizes and the numbers scale down. Needs an AX5 screenshot. |
| 16 | Pass | Ember only on the strain ring and gauge. Status colours only for judgements. No blue. |
| 17 | Pass | Every status colour has a word: chip, legend, "N to watch", dot plus word, VO values. |
| 18 | Pass | No yellow, green, ember or iris text. Chip text uses the A pairs. |
| 19 | Pass | Bars and rings use status, ember or iris fills on card. Hair is used only for tracks and empty cells. |
| 20 | Pass | Header text over orbs is ink or ink2. Banner text on the tint is ink. |
| 21 | Pass | The stress, health monitor and week charts each open with a takeaway sentence. |
| 22 | N/A | No Swift Charts on Today. Hand-drawn bars, no gridlines needed. |
| 23 | Pass | Bars start from 0, scores on 0–100 and 0–21. |
| 24 | Pass | One series per chart. Direct labels in the stage row. |
| 25 | Pass | Gaps and "Not sent" are shown as such, never zeros. FreshnessChip is always in the header. |
| 26 | Partial | Today bars aren't scrubbable. Detail lives behind a tap (score detail, MetricSheet), and VoiceOver reads every hour. |
| 27 | Pass | No tab animation. Press 0.97 and ring ticks only. The day-tap scroll uses `Motion.morph`. |
| 28 | Pass | One orchestrated moment (the ticks, first open of the day) plus the orbs. No stagger. |
| 29 | Pass* | TickRing and the orbs honour Reduce Motion, and `Motion.animate` is used for the scroll. Increase Contrast and Bold Text not yet checked on device. |
| 30 | Pass | Rings, day circles, panels, heat-map rows, day cards and chips are labelled elements with value and status. Icon buttons are labelled. |

## Open issues
- Screenshots in light, dark and AX5 are still needed to confirm items 15, 29 and the masking at the bottom of the orbs.
- If D adds a severity to `Flag` (or `OrbBackground` takes a `StatusTier`), switch the orb status so low recovery shows red.
