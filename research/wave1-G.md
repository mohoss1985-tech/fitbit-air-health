# Wave 1 · G · Body tab (lab-result panels)

File: `MRH1/PanelViews.swift` (only file edited).

## What I built
- **`PanelsView(initial: Panel = .heart)`** is the Body tab. `PanelsView()` still compiles, so `Route.panels` and ContentView work unchanged.
  - The nav bar has "Body" in the principal slot, with "4 panels, 14 results" in caption beneath it.
  - A round menu button (`RoundIconButton` → `AppNav.showMenu`) sits top-left. It shows only when the view is the tab root (`!isPresented`) and an `AppNav` is in the environment, which is read as an optional so nothing crashes before D injects it.
  - The primary element is a summary sentence in `title`: "2 results to watch today." / "All 11 results in your usual range." / "No results yet." / "Reading Apple Health…". A graphite line in `body` sits under it.
  - Then `PillPicker` with Heart · Lungs · Sleep · Activity (`Panel.allCases`, `.short` labels). Switching cross-fades over 200 ms with opacity only.
  - Next comes the selected panel's card, then the footer.
- **`PanelDetailView(panel:)`** is kept and reachable through `Route.panel`. It shows the same card and footer for one panel.
- **Panel card** (`Card`, one per screen, so no card-in-card):
  - The header is the panel title plus a graphite count: "All in range" / "1 to watch" / "3 of 4 in range" / "Waiting for sync".
  - Rows are separated by 0.5 pt hair rules.
- **Result row** reads label · value+unit (`ValueText .headline`) · `StatusChip(state:)` (direction-aware, can say Out of range).
  - Below that: `RangeStrip` (dot-matrix) for vitals (Heart and Lungs panels) or `BaselineRibbon` for Sleep and Activity, then a 7-day `Sparkline` in ink.
  - The sub-line shows "Your normal 52–61" from the personal baseline. While there is no baseline yet it shows C's `earlyReadText`. With no baseline and no early-read text, it shows "Typical …".
  - Tapping opens `MetricSheet(state:)` through a local `.sheet(item:)`. `Route` has no metric case, which matches A's `MetricRow(id:)` deviation.
- **Missing data** (§5, three states, never 0):
  - HRV and skin temperature with no data (`MetricID.isNotSentByGoogle`) get a "Not sent by Google Health" `NotSentLabel` with a one-line explanation. These rows still open the sheet that explains the metric.
  - VO2 max is a static Not-sent row in Activity. There is no `MetricID` for it.
  - Every other empty metric shows "—" plus `NotSentLabel` from `health.missing(_:)`, mapped `MissingState` → `NotSentKind`. Before the first refresh it reads "Waiting for sync".
  - A stale nightly value keeps its number and the sub-line says "Last value shown. Waiting for sync".
- **Blood pressure** is a row in Heart: "No sensor", with "Fitbit Air has no blood-pressure sensor, so MRH1 can't show it."
- **Early baseline**: if any result in the panel has fewer than 14 history days, the panel shows "Early read: N of 14 baseline days. Ranges settle as nights add up."
- **Empty state**: the summary reads "No results yet." and explains the Google Health → Apple Health sync. Every row shows its missing state.
- Pull to refresh (`health.refresh()`) on both screens. Footer: "Your normal is the last 30 days…" plus "Wellness estimates, not medical advice."
- VoiceOver: each row is one button element whose label holds the name, value, unit, status word, direction text, range and the last 7 values. The hint is "Opens what this result means".

## Deviations
- The summary says "…to watch **today**" rather than "this week". The count comes from the latest readings, the same ones as the row chips, so "week" would be inaccurate.
- No orbs on Body, even though the mock shows them. DESIGN_SPEC §3 allows orbs on Today and Live only.
- The mock's "Walking heart rate" row is not built, because it has no `MetricID` (optional per research/07).
- I did not use `MetricRow(id:)` from A. It always draws a ribbon (Body needs the dot-matrix strip for vitals), it shows `info.sub` instead of "your normal X–Y", and it has no explanation line for Not-sent rows. I composed A's components instead.

## Checklist (research/03 §9), Body + PanelDetail
| # | | Note |
|---|---|---|
| 1 | Pass | The summary sentence (`title`) is the one primary element |
| 2 | Pass | Text colours: ink, graphite, and chip text only. Weights: regular/medium, semibold for numerals and headline |
| 3 | Pass | The value is visually dominant (headline numerals). The label is body/ink with a quieter caption sub |
| 4 | Pass | Section gap 32 vs in-row 4–12. Hair rules separate list rows. No card-in-card |
| 5 | Pass | ≤6 rows per panel, with the picker hiding the rest |
| 6 | Pass | Everything goes through `.typo()` (UIFontMetrics). Smallest is caption 12 |
| 7 | Pass | No light weights |
| 8 | Pass | Typo roles are monospacedDigit, plus explicit `.monospacedDigit()` on counts |
| 9 | Pass | `ValueText` aligns value and unit on the baseline (A) |
| 10 | Pass | Sentence case, no caps eyebrows, no mono. NBSP before °C |
| 11 | Pass | Only Space tokens. Gutter 20, Card padding 20 (A default) |
| 12 | Pass | Single card radius 28, no nested radii |
| 13 | Pass | Strips and sparklines sit inside the card padding |
| 14 | Pass | Rows have minHeight 44 and full-width hit areas. The menu button is 44 |
| 15 | Partial | Rows reflow vertically and the name column flexes. At AX5 the value column can squeeze the name. Not verified in the simulator |
| 16 | Pass | Ember only inside A's ribbon dot. Status colours only in chips and strips. No blue |
| 17 | Pass | Each chip carries a word. Missing states are words |
| 18 | Pass | Graphite text on card ≥5.4:1. No yellow/ember text |
| 19 | Pass | A's marks. Hair separators are lighter than graphite labels |
| 20 | Pass | No text on tints or orbs |
| 21 | n/a | No full charts. Units sit next to values |
| 22–23 | n/a | Sparklines have no axes |
| 24 | Pass | One ink line per sparkline |
| 25 | Pass | Missing data shows "—" plus a state word, never 0 |
| 26 | n/a | Sparklines aren't scrubbable. Values are in the sheet and in VoiceOver |
| 27 | Pass | Panel switch is a 200 ms opacity cross-fade. No tab animation |
| 28 | Pass | No stagger, no orchestrated moment |
| 29 | Pass | Opacity-only transition. Press scale comes from A's PressStyle (Reduce Motion-safe) |
| 30 | Pass | Rows are combined buttons with value, unit, status and last-7 values. The menu button is labelled. No §8 tells: no tile grid, no tinted icon circles, no emoji |

## Open issues
- If D also adds a menu button for the Body tab in ContentView, there will be two. I show mine only when `AppNav` is in the environment and the view isn't pushed.
- `Route` has no metric case yet. The sheet is presented locally (same as A).
- No screenshot taken yet (integrator step).

## Build
`build/G`: **BUILD SUCCEEDED**, with no errors or warnings from PanelViews.swift.
