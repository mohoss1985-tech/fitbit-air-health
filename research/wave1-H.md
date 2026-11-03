# Wave 1 — Agent H: Trends tab, weekly report, body age

Files: `MRH1/TrendsView.swift`, `MRH1/WeekViews.swift`. Build `build/H`: **BUILD SUCCEEDED**, with 0 errors and 0 warnings in my files.

## What I built

### TrendsView (Apple Trends grammar, research/02 Decision 6)
- **Intro line:** "Last 7 days compared with the 7 before." (body, graphite).
- **What changed:** the trends that moved meaningfully, biggest relative move first. "Meaningfully" is ≥3 % of the week-before average, which is the same rule as `Insights.trend`. Skin temperature is already a delta around 0, so it uses an absolute 0.25 °C instead. If nothing moved, one card says "Nothing moved meaningfully this week."
- **`TrendCard`** shows the following:
  - Header row: the metric name (label, graphite) and a status chip.
  - Status chip: "Better" (good) or "Watch" (limit), each with a dot. Neutral metrics (SpO2, skin temperature) get an ink "Up"/"Down" word and no colour.
  - Takeaway sentence (headline, ink), for example "Resting heart rate averaged 3 bpm lower than the week before."
  - For a concerning change only, one calm action in graphite after the sentence ("Easier days and earlier nights help it settle.").
  - Swift Charts with 14 grey bars (graphite2; the week before at 55 %, with a 2 pt top radius) starting from 0.
  - Two lines: a graphite `RuleMark` for the week-before average across the first 7 bars, and a last-7-days `RuleMark` across the last 7. The second line is in the status colour only when the change is meaningful and directional, otherwise ink.
  - Direct value labels on each line, so there's no legend. A caption row underneath reads "Week before" and "Last 7 days".
  - `.mrhGrid()` from B (dotted hair, max 3, no default axes or blue) and `MRHChart.line`.
  - VoiceOver label and value with both real averages.
  - Tapping the card opens `MetricSheet` with the scrubbable chart.
- **All metrics:** a 56 pt disclosure row ("All metrics · N steady", chevron rotates with `Motion.morph`). It expands to the steady trend cards in the same grammar. Below them, a list of the metrics that have no trend yet, each with `NotSentLabel` (Not sent / Waiting for sync) or "Needs two weeks to compare.". Every one of them opens `MetricSheet`, so all 13 v0.4 metrics stay reachable.
- **Empty state:** "Trends need two weeks of data" plus "Early read: N of 14 baseline days." (from `MetricState.baselineDays`).
- **Your week:** `WeeklyReportCard()`.
- **Tags and recovery:** fed by `JournalStore.discoveries` (C).
  - With discoveries: each sentence on its own row, then "Patterns from N tagged days, not causes."
  - Without: a dot-matrix progress row of 5 dots (ink = tagged, hair = remaining) with `journal.progressText`, and a "Tag today" capsule that sets `nav.showJournal = true`.
- **Body age:** `BodyAgeCard()`.
- **Footer:** "Wellness estimates, not medical advice."
- Gutter 20, section gap 32, card gap 12, paper background, `.refreshable`, `.navigationTitle("Trends")`.

### WeekViews
- **`TrendCopy`** (internal enum, shared by both files): `reading`, `changed`, `sentence`, `action`, `tier`, `word`, `magnitude`, and `value`/`delta` with a non-breaking space before the unit. The copy is deterministic, has no exclamation marks, and stays at 14 words or fewer.
- **`WeeklyReportCard()`:** the init is unchanged, so Today still compiles.
  - Header: "Weekly report" and the date range.
  - Five rows, not a tile grid: average recovery, average sleep, sleep debt (with a "Watch" word over 2 h), average steps, and workouts "of 150" min. Values use `ValueText(.headline)`.
  - "Best change" (goodText) and "To work on" (limitText) with the rewritten sentences.
  - A **ShareLink "Share for a doctor"**: a plain-text summary of the report, every metric's week-before → last-7-days average (or "not sent by Google Health" / "not enough data"), body age, the data source line and the disclaimer.
- **`BodyAgeCard()`:**
  - The estimate as `ValueText(... unit: "years", .metric)` with "vs N by the calendar", then the sentence.
  - Each factor as a row: label, signed "−1.2 y" in goodText/limitText, a diverging bar either side of an ink centre hairline (the same grammar as the score contributors), and the detail caption.
  - A 44 pt ⓘ that opens `ExplainSheet`.
  - No-DOB state uses `BodyAge.missingBirthDateText` (the "Apple Santé" copy is fixed). Not enough data: "Needs at least two signals…".

## Deviations
- **MetricSheet:** opened with `.sheet(item:)`, not through a `Route`, because `Route` has no metric case. This matches A's `MetricRow`.
- **Missing days:** the bars come from `Insights.Trend.previousValues/recentValues`, which hold values only, with no dates. A day with no data is skipped instead of drawn as a gap. Fixing this needs dated values from C's `Trend`.
- **Trend card interaction:** the card itself isn't scrubbable (checklist 26). Its two averages are labelled directly, and the scrubbable chart is one tap away in MetricSheet.
- **Export:** plain text only, not a rendered PDF or image. Plain text is the most useful thing to hand a doctor and works with Mail, Messages and Files.
- **Sentences:** I wrote my own trend sentences (TrendCopy) instead of using `Insights.Trend.sentence`. The Insights version runs to about 16 words, uses "(5%)" fake-precision brackets, and for skin temperature computes a % against a value near 0. Insights itself is untouched.

## 30-item checklist (research/03 §9), Trends + cards
1. Pass: one primary, the first changed trend card (headline sentence plus chart).
2. Pass: ink, graphite and status text colours; regular plus semibold/medium.
3. Pass: values and sentences lead, labels are graphite.
4. Pass: 32 between sections, 12 inside, no card in a card (rows inside cards use hairlines).
5. Pass: steady metrics sit behind "All metrics".
6. Pass: all text uses `.typo()` roles (UIFontMetrics, Dynamic Type), with nothing under 11 pt.
7. Pass: no light weights.
8. Pass: Typo roles and ValueText are monospaced-digit.
9. Pass: ValueText keeps value and unit on the baseline, with the unit graphite.
10. Pass: sentence case, NBSP before units, `.formatted()` numbers and dates.
11. Pass: spacing tokens only.
12. Pass: card 28, chip 8, bars 2.
13. Pass: the chart spans the card content width at the 20 pt padding.
14. Pass: card buttons, the disclosure row (56), ⓘ (44), and the share and tag capsules (44).
15. Partial: rows wrap with `fixedSize(vertical)`; the factor and report rows are HStacks that should be checked at AX5.
16. Pass: no ember on Trends; green and yellow only as status.
17. Pass: every status colour carries a word (Better/Watch, younger/older sign, "Watch" on sleep debt).
18. Pass: small coloured text uses goodText/limitText.
19. Pass: bars are graphite2 context, and the highlighted average line is ink or status at 2.5 pt.
20. Pass: no text on orbs.
21. Pass: the sentence is the takeaway, and units appear on the direct labels only.
22. Pass: `.mrhGrid()`, with no default axes.
23. Pass: bars start from 0.
24. Pass: one highlighted series (the new average), grey context, direct labels.
25. Partial: see Deviations (skipped days are not drawn as gaps); missing metrics show NotSentLabel.
26. Partial: see Deviations; scrubbing lives in MetricSheet.
27. Pass: disclosure uses morph 300 ms; no tab animation.
28. Pass: no stagger.
29. Pass: `Motion.animate` honours Reduce Motion.
30. Pass: combined elements, chart label and value with real numbers, labelled ⓘ.

## Open issues
- Missing days should appear as gaps; this needs `Insights.Trend` to carry dates (C).
- On Today, `WeeklyReportCard` now has a ShareLink, so check it fits there visually (owner: Today agent).
- Not yet verified at AX sizes or in dark mode on device.
- No screenshot taken: `simctl install` on the shared booted iPhone 18 Pro hung for more than 3 minutes while other agents were using it, so I stopped it. The checklist above comes from code review, not from pixels. Re-check Trends in the Wave 2 screenshot pass (`-demo -tab trends`).
