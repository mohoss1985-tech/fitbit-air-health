# 03 — UI craft: hierarchy, type, space, colour, charts, motion (enforceable rules)

Agent: UI-craft research · 2026-11-02 · Scope: rules a SwiftUI build agent can check screen by screen.

## Sources (read for this report)

- Refactoring UI chapter list and tactics: https://www.refactoringui.com/ (secondary notes: https://dev.to/updivision/book-review-refactoring-ui-by-adam-wathan-steve-schoger-2f7m)
- Apple HIG Typography (sizes, weights, Dynamic Type tables): https://developer.apple.com/design/human-interface-guidelines/typography
- Apple HIG Accessibility (contrast, hit targets, Reduce Motion): https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple HIG Charts and Charting data: https://developer.apple.com/design/human-interface-guidelines/charts · https://developer.apple.com/design/human-interface-guidelines/charting-data
- Emil Kowalski: https://emilkowal.ski/ui/great-animations · https://emilkowal.ski/ui/you-dont-need-animations · https://emilkowal.ski/ui/7-practical-animation-tips · https://animations.dev/
- Rauno Freiberg, Invisible details of interaction design: https://rauno.me/craft/interaction-design
- Vercel Web Interface Guidelines: https://vercel.com/design/guidelines
- Anthropic `frontend-design` skill: https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md
- ui-skills (ibelick) and its playbook: https://github.com/ibelick/ui-skills · https://www.ui-skills.com/playbook (forks: https://agent-skills.md/skills/ckorhonen/claude-skills/ui-design, https://skills.sh/ihlamury/design-skills/anthropic-ui-skills)
- Tufte (data-ink, chartjunk, sparklines, small multiples), course notes: https://www.cc.gatech.edu/~stasko/7450/16/Notes/tufte.pdf
- Datawrapper line charts and colour guides: https://www.datawrapper.de/blog/line-charts · https://www.datawrapper.de/blog/colors-for-data-vis-style-guides
- Material data-viz accessibility (by the authors of Material's chart guidelines): https://m2.material.io/blog/data-visualization-accessibility · https://www.smashingmagazine.com/2022/07/accessibility-first-approach-chart-visual-design
- Laws of UX: https://lawsofux.com/

(m3.material.io's data-viz page returned 404, and the upstream ui-skills README only lists CLI commands. The playbook was used instead.)

## 1. Visual hierarchy rules

1. **One primary per screen.** Every screen has exactly one element a stranger notices first: Today → the readiness/recovery score; Live → the current BPM; Body → the body diagram/state; Trends → the selected metric's chart. Everything else is visibly secondary. The `frontend-design` skill says to "spend boldness in one place… keep everything around it quiet". Von Restorff (Laws of UX): the item that stands out is the one people remember. That only works if one thing stands out.
2. **Emphasise by de-emphasising** (Refactoring UI). Make the hero stand out by turning everything else down: graphite text, lighter weight, smaller size. Don't make the hero bigger and bolder in an arms race.
3. **Use colour and weight before size.** Use 2–3 text colours (ink, graphite, a lighter tertiary) and 2 weights (Regular plus Semibold, with Bold only for hero numbers). HIG: "adjust font weight, size, and color… to help people visualize hierarchy."
4. **Labels last.** If a value's format already says what it is (e.g. "7h 42m", "62 bpm"), don't add an extra label. When a label is needed, it is quieter than the value. Value first, label second.
5. **Group by space before borders** (proximity and common region). Space between groups must be clearly larger than space inside a group, at least 2×. Don't put a card inside a card. Add a divider only when space can't do the job.
6. **Use the 3-level rule per card.** Each card has at most three typographic levels: value, label, meta. If you need a fourth, the card is doing two jobs, so split it.
7. **Chunk (Miller/Hick).** Keep ≤5–7 metric tiles per visible group. Use progressive disclosure for the rest (HIG: "let people choose when they want additional details").

## 2. Typography for numeric dashboards

- Use **SF Pro via text styles** (`.largeTitle … .caption2`) so Dynamic Type works. The iOS default sizes are LargeTitle 34/41, Title1 28/34, Title2 22/28, Title3 20/25, Headline 17/22 semibold, Body 17/22, Callout 16/21, Subhead 15/20, Footnote 13/18, Caption1 12/16, Caption2 11/13. **Never go below 11 pt.** Custom sizes use `.system(size:, relativeTo:)` or `@ScaledMetric`.
- **No Ultralight/Thin/Light weights** for anything below ~34 pt (HIG). Hero numerals may use Light only at ≥48 pt and only if contrast is ≥4.5:1.
- **Use tabular (monospaced) digits everywhere numbers update or line up** (`.monospacedDigit()`). This is mandatory in the ui-skills fork and recommended by Vercel. Live BPM, min/avg/max rows, and axis labels must not jitter.
- **Give hero numbers a contrasting rhythm.** Set a big numeral (e.g. 56–72 pt, `.rounded` or `.default` design, tight tracking) with a unit at ~40–50% of its size, baseline-aligned (Refactoring UI: align by baseline, not centre) and in graphite. Use `Text` concatenation or `HStack(alignment: .firstTextBaseline)`.
- Use **one family**, SF Pro (Rounded allowed for numerals only, and the same everywhere). Don't use monospace fonts for small labels; that is an AI tell (`frontend-design`).
- Use **sentence case** labels and **no ALL-CAPS tracked eyebrows** (`frontend-design`, ui-skills).
- Keep units together with a non-breaking space (`62\u{00A0}bpm`). Use the real ellipsis "…". Use locale-aware number and date formatting (`.formatted()`).
- Tighten tracking slightly on large display text and loosen it on small text. Line height scales with size.

## 3. Spacing and layout system for iPhone

- **Use a 4-pt base scale: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 56 · 72.** Put it in tokens (`Space.s1…`). Don't use magic numbers in views.
- Screen gutter: **20 pt** (16 pt on SE/mini widths). Inside card padding: 20 pt. Between cards in a group: 12 pt. Between sections: 32–40 pt. Section header to its content: 12 pt.
- **Nested radii are concentric:** inner radius = outer radius − padding (Vercel, ui-skills). For example, a card at 28 pt with 16 pt padding gives inner chips/charts 12 pt.
- **Start with too much white space, then remove it** (Refactoring UI). Don't fill the screen just because it's there.
- Align every chart's leading edge to the card's text leading edge. Consider trailing Y-axis labels so ticks don't stick out (HIG Charts).
- Respect safe areas. Horizontal scrollers (week strip, chips) show 16–32 pt of the next item (ui-skills).
- Hit targets are ≥44×44 pt (HIG default; 28 pt is the absolute minimum). Leave ~12 pt between bezelled controls (HIG).
- At accessibility text sizes, **reduce columns**: 2-up tiles become 1-up, using `ViewThatFits` or `dynamicTypeSize >= .accessibility1` (HIG).

## 4. Colour (status vs brand, contrast)

- **Keep roles separate.** Ember is the brand only (today, focus, strain). Green/yellow/red are status only. Iris is sleep/night. Grey carries context. Datawrapper: "grey is the most important colour in data viz". Use it for comparison lines, previous periods, and missing data. ui-skills: one accent per view, with neutral headings.
- **Contrast targets (HIG/WCAG AA):** text ≤17 pt needs ≥4.5:1. Text ≥18 pt or bold needs ≥3:1. Chart marks and graphics need ≥3:1 against their background (WCAG 1.4.11). Check light **and** dark.
- **Measured on the moodboard tokens** (WCAG ratio, against card #FAF9F7 unless noted):
  - ink on paper: 15.5 ✓
  - graphite #77726C on card: 4.53 ✓ (just passes), on paper: **4.0 ✗ for small text**. Darken graphite to about #6B665F, or keep secondary text on cards.
  - ember #F0582A: 3.25. OK for marks and ≥18 pt numerals, **not for small text**.
  - good #2F9D68: 3.25. Marks only, not small text.
  - yellow #E6B820: **1.78 ✗** even as a mark. Never use it as text or as a thin line; use it as a fill with an ink/dark-yellow (#8A6A08) label.
  - iris #8B88F0: 2.9 ✗. Darken it for lines.
  - hair #DFDBD5: 1.31. Fine for gridlines, never for data.
  - Chips: #237A50/#DDF0E4 4.45, #8A6A08/#FBF0C8 4.44 (both just below 4.5, so bump them darker or use semibold ≥14 pt), #A92C2C/#F8DCD8 5.26 ✓.
- **Never use colour alone** (HIG, Vercel, ui-skills). Status always comes with a word ("Good", "Limit", "High") and/or a shape or SF Symbol.
- Test green vs red with a colour-blindness simulator. They must also differ in lightness (Datawrapper).
- Don't put grey text on coloured or gradient backgrounds. Use a tint of the background hue instead (Refactoring UI). Text over orbs must be ink.
- Support **Increase Contrast** with an alternate token set, and keep the gradients from washing out the text.

## 5. Chart design rules

- **Maximise data-ink** (Tufte). Don't use boxes around plots, shadows on lines, 3D, or decorative gradient fills under every line. An area fill is allowed only when it encodes something (e.g. a normal range band).
- **Gridlines:** use 2–4 horizontal hairlines in `hair`, with no vertical grid unless the x-axis needs it. Gridlines are lighter than axis labels, and labels are lighter than the title (Datawrapper). If the chart can be scrubbed, use even fewer gridlines (HIG).
- **Ticks:** use familiar sequences (0, 50, 100; 40, 60, 80), not 37, 62, 87 (HIG). Use short labels and put units in the title or subtitle, not on every tick.
- **Y baseline:** bars start at 0. Lines/HR may use a dynamic range, but **pad the range** and include zero if the data comes near it (HIG, Datawrapper). Use fixed domains for scores (0–100) so days can be compared.
- **Title = the takeaway.** Example: "Resting HR 3 bpm below your 30-day average". Don't title it "Resting HR chart" (HIG: "descriptive titles… highlight actionable takeaways").
- **Label lines directly** at their right end, in the line's colour. Avoid legends (Datawrapper). Use one highlighted series in colour and context series in grey.
- **Annotate** the one thing that matters: today's point, the min/max, the personal-baseline band, "Not sent" gaps. Show gaps as gaps, never as interpolated zeros.
- **Sparklines** (Tufte) show shape, not value. No axes. Mark the last point with a dot and print the current value next to it. Use the same time window for every sparkline in a group.
- **Range bars** (min–avg–max, sleep windows): draw a capsule from min to max in a tint, a solid tick/dot for avg or current, and a grey track for the full scale. The personal normal range is a soft band behind the marks.
- **Use small multiples** with shared scales for the same metric across days. Keep colours, chart type and layout consistent for the same dataset (HIG continuity).
- **Interaction:** the entire plot is a scrub target (HIG). The scrub shows a value bubble, the date/time, and a vertical rule. Critical information must never require interaction to see.
- Use common chart types (line, bar, range, point) and avoid gauges/donuts unless they encode a bounded score (HIG).

## 6. Motion rules (Kowalski, Freiberg, HIG). These match PROJECT_NOTES.

- Every animation must have a purpose: feedback, spatial origin, a state change, or a rare delight. Ask "how often will they see this?" Frequent actions get no motion. **Tab switches are not animated.**
- UI animations take **<300 ms**. Enter: ease-out `(0.23,1,0.32,1)` 220 ms from scale 0.96, **never from scale 0**. Press: scale 0.97, 160 ms. Morph: `(0.77,0,0.175,1)` 300 ms. Sheets: `(0.32,0.72,0,1)` 500 ms in / 200 ms out. **Never ease-in for entrances.**
- **Interruptible:** use springs or `withAnimation` that retarget mid-flight. Drags track the finger 1:1 and keep throw velocity (Freiberg: momentum). Destructive actions only commit when the gesture ends.
- Transform origin = the trigger. Popovers and sheets grow from their button.
- Numbers use `.contentTransition(.numericText())`. Live BPM ticks without layout shift (tabular digits).
- Don't stagger fade-and-slide-up on every card ("reads as AI-generated", `frontend-design`). Use **one orchestrated moment** per screen at most, e.g. the score ring filling once on first load.
- **Reduce Motion:** swap translations for fades, freeze gradient drift, no blur in/out, tighter springs (HIG).

## 7. Accessibility

- Dynamic Type works up to AX5 without truncating key values. Hero numbers may cap at about `.accessibility2` via `.dynamicTypeSize(...)` but must still scale.
- Every chart has an `accessibilityChartDescriptor` (Audio Graphs) or a summary label with chart type, axis meaning, and bounds. Use actual values, not "good". Write "June 6", not "6/6"; "60 minutes", not "60m". Hide tick labels from VoiceOver (HIG Charts).
- Tiles combine into one element ("Resting heart rate, 58 beats per minute, good, 3 below average"). Icon-only buttons have labels.
- Hit targets ≥44 pt. Check contrast in light and dark and with Increase Contrast. Status is never colour-only. Reduce Motion is honoured. Bold Text doesn't break layouts.

## 8. "AI / vibe-coded" tells. Any one of these fails review.

1. Identical rounded cards with one radius, one soft `rgba(0,0,0,.1)` shadow, and a gradient wash on everything (`frontend-design`).
2. "Big number + small label + three supporting stats + gradient accent" hero by default.
3. Tracked ALL-CAPS eyebrows above every section. Middle-dot meta strings "A · B · C". "WORD — fragment" labels. "→" on every link.
4. Monospace for small data labels. One word in a headline accented in a different colour or italic.
5. Fade-and-slide-up stagger on every card. Bouncy springs on every toggle. Glows on primary buttons (ui-skills).
6. Emoji or random SF Symbols as decoration. Icon-in-a-tinted-circle on every row.
7. A rainbow of accent colours. Status colours used as brand. Purple-blue gradients (the brief bans blue).
8. Gradient fills under every line chart. Default Swift Charts styling left untouched (blue marks, default grid, auto ticks).
9. Placeholder or generic copy ("Your health at a glance!", "Insights"). Exclamation marks. Numbers without units or context.
10. Fake precision ("72.384 bpm"). Zeros where data is missing.
11. Everything centred. Everything the same weight. No clear primary.
12. **A warning for this project:** `frontend-design` explicitly lists "warm cream background + terracotta accent" as an AI-default look. MRH1's paper + ember is close to this. It stays distinctive only if the rest is specific to the subject: physiological chart types (range bars, baseline bands, hypnogram), real data density, the orb shader, and disciplined type. Without those, it reads as the default.

## 9. 30-item review checklist (run on every SwiftUI screen; each item is pass/fail)

**Hierarchy**
1. [ ] Exactly one primary element. A squint test (blur the screenshot) shows it first.
2. [ ] Max three text colours and two weights in body content (Bold only on hero numerals).
3. [ ] Value before label. Labels are quieter than values. No redundant labels.
4. [ ] Gap between groups ≥2× gap inside groups. No card-in-card. Dividers only where space fails.
5. [ ] ≤7 tiles per visible group. Extra detail sits behind a tap.

**Typography**
6. [ ] All text uses text styles or `relativeTo:`. Nothing below 11 pt.
7. [ ] No Light/Thin/Ultralight below 34 pt.
8. [ ] Every changing or aligned number uses `.monospacedDigit()`.
9. [ ] Hero number and unit are baseline-aligned. The unit is smaller and graphite.
10. [ ] Sentence case. No ALL-CAPS tracked eyebrows. No monospace labels. Units use non-breaking spaces. Numbers are formatted for the locale.

**Layout**
11. [ ] Only spacing tokens (4-pt scale) are used. Gutter is 20 pt. Card padding is 20 pt.
12. [ ] Nested radii are concentric (inner = outer − padding).
13. [ ] Chart leading edges align with card text. Nothing sticks out past the gutter.
14. [ ] All tappable things are ≥44×44 pt.
15. [ ] The layout reflows at AX sizes (fewer columns, no clipped key values).

**Colour**
16. [ ] Ember appears only as brand/focus. Green/yellow/red appear only as status. No blue.
17. [ ] Every status has a word or shape alongside the colour.
18. [ ] Small text ≥4.5:1 and large/bold ≥3:1, in light and dark. Yellow/ember/green/iris never used as small text.
19. [ ] Chart marks ≥3:1 against the card. Gridlines are lighter than labels, and labels are lighter than titles.
20. [ ] No grey text on gradients or tints. Text over orbs is ink.

**Charts**
21. [ ] The chart title states the takeaway. Units are in the title or subtitle, not repeated on ticks.
22. [ ] 2–4 hairline gridlines. Familiar tick values. Default Swift Charts styling has been overridden.
23. [ ] Correct baseline: bars from 0, scores on a fixed 0–100, lines padded.
24. [ ] One highlighted series. Context in grey. Direct labels instead of a legend.
25. [ ] Missing data shows as a gap or "Not sent", never 0. "Latest sample N min ago" is visible where relevant.
26. [ ] The plot is scrubbable with a value bubble. No critical information is hidden behind interaction.

**Motion and accessibility**
27. [ ] No animation on tab switches or frequent actions. Every animation is <300 ms (sheets excepted), ease-out, interruptible, and never scales from 0.
28. [ ] At most one orchestrated moment per screen. No per-card stagger.
29. [ ] Reduce Motion gives fades only and frozen gradients. Increase Contrast and Bold Text are verified.
30. [ ] VoiceOver: tiles are combined elements with value, unit, and status. Charts have descriptors with real values. Icon buttons are labelled. None of the section 8 tells are present.
