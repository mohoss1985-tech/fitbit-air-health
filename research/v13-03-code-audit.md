# v1.3 · 03 · Code audit: Today layout + B1–B5

Read-only audit of the working copy (2026-11-08). Line numbers are from the current files.
Build check: `xcodebuild` could not run because the sandbox blocks CoreSimulator and writes to `build/audit/Logs`, so nothing was compiled. Run it outside the sandbox.

## 1 · Today module map (current order)

`TodayView.body` (TodayView.swift:23–63) is `ScrollViewReader { ScrollView { VStack { header(proxy); VStack(cards) } } }`.
The header (83–117) sits on one `OrbBackground` (480 pt, masked) that also bleeds up behind the status bar.
Heights are for an iPhone 15-class screen at default Dynamic Type. The first screen shows about 700 pt.

| # | Module | File:line | Struct / member | ≈ height | Dependencies |
|---|---|---|---|---|---|
| 1 | Top bar (menu · greeting · +) | TodayView.swift:119 | `topBar` | 44 | `nav.showMenu`, `nav.showJournal`, `health.greeting` |
| 2 | **Day circles M–S** | TodayView.swift:86–89, 340–382 | `private struct DayCircles` | 56 (+24 gap) | `health.history.suffix(7)`; tap → `selectedDay = day` + `proxy.scrollTo("week", anchor: .top)` |
| 3 | Verdict headline | TodayView.swift:90, 136–172 | `verdict` | 60–70 | `health.recovery`, `health.strain`, `Scores.todayStrainTarget`, `CoachRules.todayCap`, clock |
| 4 | **Three gauges** (Sleep · Recovery · Strain) + CoachMark | TodayView.swift:96–100, 202–282 | `rings` / `heroRing` / `smallRing` | 200 | `animateRings` (TickRingGate), `Route.score(...)`, `typeSize` |
| 5 | Status lines (Sync, tier chip, freshness, demo, signals, stale-night note) | TodayView.swift:286–319 | `statusLines` | 90–130 | `health.latestSampleDate`, `recoveryTier`, `Demo` |
| — | header bottom padding | :105 | | 32 | |
| 6 | Coach note (optional) | TodayView.swift:29, 69–79; CoachViews.swift:168 | `CoachNoteCard` | 0 / 150–190 | `coachOn`, `proactive`, `CoachRules.evaluate(...).note`, `HealthMonitorCard.vitals` |
| 7 | Strain target | TodayCards.swift:56 | `StrainTargetCard` | 170 | `CoachRules.todayCap`, `IntensityCap.strainTarget` |
| 8 | Stress today | TodayCards.swift:95 | `StressCard` | 200 | `health.stressHours` |
| 9 | **Body panels** | TodayCards.swift:211 | `PanelsStrip(open:)` | 110 | closure `nav.tab = .body` |
| 10 | Drift banner (≥2 vitals off) | TodayCards.swift:255 | `DriftBanner` | 0 / 110 | `HealthMonitorCard.vitals` |
| 11 | Health monitor heat map | TodayCards.swift:281 | `HealthMonitorCard` | 260 | own `@State sheet` |
| 12 | Last night | TodayCards.swift:390 | `LastNightCard(session:)` | 180 | `health.lastSleep`; CoachMark `.sleepTotal` |
| 13 | "Your week" label | TodayView.swift:37–39 | `SectionLabel` `.id("week")` | 40 | **scroll target of the day circles** |
| 14 | Sleep balance | TodayCards.swift:438 | `SleepBalanceCard` | 150 | own `@State info` |
| 15 | Week strip (swipeable day cards) | TodayWeek.swift:7 | `WeekStrip(selected:)` | 170 | `@Binding selected` = `$selectedDay`; `.scrollPosition(id:)` centres the chosen day |
| 16 | Weekly report (Mondays) | WeekViews.swift:102 | `WeeklyReportCard` | 300 | weekday == 2 |
| 17 | Journal | TodayCards.swift:510 | `JournalCard` | 120 | `nav.showJournal` |
| 18 | Footer | TodayView.swift:323 | `footer` | 60 | `health.lastRefresh` |

The header is about 620 pt, so on a 6.1" screen only modules 1–5 are visible before scrolling. The day circles take about 80 pt (row plus gap) at the top of that first screen. "Your week" starts about 1,700 pt down (roughly 2.5 screens). Body panels start about 1,150 pt down.

### What the day-circle strip does
- Tapping a day **does not change the gauges, the verdict or the header.** The gauges always show `health.recovery`, `sleepScore` and `strain`, which are today's values. The tap only sets `selectedDay`. `WeekStrip` then centres and outlines that day card through `.scrollPosition(id:)` (TodayWeek.swift:45, 65, 89), and the page scrolls to `"week"`.
- So the strip is just a shortcut to Your week, placed above the score.
- The day circles have no other users: the struct is `private` and has only one call site.

### What breaks if it moves below the gauges
- Nothing functional, as long as it stays inside the same `ScrollViewReader` closure, because it needs `proxy`.
- If it moves out of `header(_:)`, it leaves the orb background. That is fine: the orb's mask fades it out at 60–100 %, so the gauges keep it.
- If it lands directly above `WeekStrip`, `scrollTo("week")` becomes a tiny jump, or a backward jump if the label sits above the circles. Keep `selectedDay = day` and drop or keep the scroll; both are harmless.
- Copy to update: the accessibility hint "Shows this day in Your week" (TodayView.swift:373), the doc comment at TodayWeek.swift:5–6, and the order comment at TodayView.swift:3–6.
- `OrbBackground` stays 480 pt. The header gets about 80 pt shorter, so the orb shows a little further into the first card. Check this in a screenshot; it is not a bug.

### Safest way to reorder (one file, no state lift)
1. In `header(_:)`, delete lines 86–89 (`DayCircles`). The header becomes `topBar → verdict → rings → statusLines`, which puts the gauges first.
2. Make the card stack a function, `cards(_ proxy: ScrollViewProxy)`, or pass `proxy` in. That lets `DayCircles` sit inside the "Your week" block:
   `SectionLabel("Your week").id("week") → DayCircles(... ) { selectedDay = $0 } → SleepBalanceCard → WeekStrip(selected: $selectedDay)`.
3. Move that whole block (label + circles + balance + strip) higher, and move `PanelsStrip` (with `DriftBanner` directly above it) up next to the gauges. One candidate order, which the research agents should settle: header → CoachNote → DriftBanner → PanelsStrip → Your week → StrainTarget → Stress → HealthMonitor → LastNight → WeeklyReport → Journal → footer.
4. `selectedDay` stays `@State` in TodayView, so nothing needs lifting. Every card is self-contained and reads only the environment, so moving them is just cut and paste. The single exception is `PanelsStrip`'s closure, which captures `nav`.
5. Optional: a "Your week" jump control next to the verdict (e.g. `Button("Your week") { proxy.scrollTo("week") }`). It reuses the same id.

## 2 · Bugs: root cause and patch

### B1 · "Room for a session" vs "Big jump… ease in"
**Root cause.** Rule **L2** (CoachRules.swift:437) is added **without a `cap:`**. With Recovery 63 %, the only cap that fires is R3 = `.moderate` (:299). `.moderate.strainTarget(10...14)` is still 10–14 (CoachLibrary.swift:27), and `afternoonVerdict` reaches its last branch: "Room for a session" (TodayView.swift:162–166). Meanwhile `pickNote` picks the L2 note, because L2 is in the morning order and `daily` mode uses the morning slot all day. The note says "ease in" and offers "Plan an easy session", while the cap the headline uses says moderate.

**Which should win:** the rules. The note is the safety-leaning signal, and v1.2's contract is that the cap drives the headline, the strain card and the coach. So L2 has to *impose* the cap that its copy promises.
```swift
// CoachRules.swift:437
add("L2", "Big jump vs your usual week: …. Ease in.", [.workoutMinutes], cap: .easy,
    note: Draft(...))           // copy unchanged
```
- **Effect:** `todayCap` becomes `.easy` and `todayStrainTarget` becomes 5–8. The morning verdict reads "Partly recovered. Keep today easy." The afternoon verdict reads "Strain x of your 5–8 target. Easy day: a walk is enough." `StrainTargetCard` reads "Easy day: a walk or mobility is enough." The template `capReason` should name it, so add this before the `R3` line (:790): `if has("L2") && cap == .easy { return "A big jump vs your usual week, so keep it easy." }`.
- **Same latent bug in L3** (:460): "Make your next session truly easy" also has no cap. Add `cap: .moderate` (no intervals). A milder alternative is to change its chip to "Plan my workout".
- **Guard against regressions** (DEBUG, in `pickNote` before `return CoachNote`):
  `assert(!(d.chips.contains { $0.contains("easy") || $0.contains("rest day") }) || capOf(fired).libraryRank <= IntensityCap.easy.libraryRank, "note \(id) asks for easy but cap is looser")`
  For this, pass `cap` into `pickNote`. It is already computed in `evaluate` at :26.

### B2 · "Why is recovery low?" answered about sleep
**Root cause: a sticky metric context.**
1. The CoachMark on `LastNightCard` opens `CoachSheet(metric: .sleepTotal)`.
2. Every chip in a sheet is sent with `about: context.metric` (CoachConversation.swift:244). `CoachEngine.send` also falls back to `focusMetric` (CoachEngine.swift:199).
3. In the template router, `if let m = metric ?? mentionedMetric(q) { return explain(m, q) }` (CoachRules.swift:709) runs **before** the recovery route (:712). So any question sent with a metric becomes `explain(.sleepTotal)`, which returns "Total sleep 7 h 10 is within your usual range."
4. `explain()`'s own default chips (:909) offer "Why is recovery low?" for sleepTotal, which closes the loop.
5. The model path has the same bias, because `prompt()` adds "about Total sleep" (CoachEngine.swift:540).

**Patch.** A named topic in the question beats the chat's metric. Add one shared helper (Builder B owns it):
```swift
// CoachRules.swift (public, near starters)
/// The metric a question is about: one it names wins; a question naming another topic
/// (recovery, strain, sleep, steps, stress, tags) drops the chat's metric; generic questions keep it.
static func focus(for question: String, context: MetricID?) -> MetricID? {
    let q = question.lowercased()
    if let named = Template.metricNamed(in: q) { return named }
    let otherTopic = ["recovery", "recover", "strain", "how hard", "step", "stress", "tag", "journal",
                      "plan", "workout", "session", "week"].contains { q.contains($0) }
        || (context.map { !$0.isSleepMetric } ?? true) && ["sleep", "slept", "night"].contains { q.contains($0) }
    return otherTopic ? nil : context
}
```
- **Router:** make `mentionedMetric` `static func metricNamed(in:)`. Then change :709 to `if let m = CoachRules.focus(for: q, context: metric) { return explain(m, q) }`. (`isSleepMetric` means `.sleepTotal/.deepSleep/.remSleep/.awake`. Write it inline as `$0.info.panel == .sleep`, the same check `CoachEngine.chips` uses at :311.)
- **Engine** (CoachEngine.swift:199): `let about = CoachRules.focus(for: question, context: metric ?? focusMetric)`. The same fix then covers the model prompt and pills.

### B3 · "Why is recovery low?" offered at 63 % (yellow)
**Hard-coded chips that ignore the tier:**
- CoachRules.swift:855: `recovery()` "what helps" branch
- :867: `explain()` not-sent branch
- :909: `explain()` default chips (the one in the recording)
- :964: `planReply` no-plan case
- :805: `today()` uses `< 34 ? low : high`, so it says "high" at 63 %

The ones at :281 and :291 are fine, because they only fire when recovery is below 34. CoachSupport.swift:62 (fallback starters) already follows the tier. Model-generated chips are free text.

**Patch.** One helper, used everywhere:
```swift
// CoachRules.swift
static func recoveryChip(_ score: Int?) -> String {
    guard let s = score else { return "What is recovery?" }
    if s < 34 { return "Why is recovery low?" }
    if s < 67 { return "What affects my recovery?" }
    return "What helped recovery?"
}
```
- Replace the literal at :855, :867, :909 and :964 with `CoachRules.recoveryChip(c.recovery?.score)`. Replace :805's ternary with it as well.
- In `starters` (:47–52), use it too, changing green from "Why is recovery high?" to "What helped recovery?" so the copy is consistent.
- **Model chips:** in `CoachEngine.map` (after the chips are parsed, near :564), rewrite any chip that `contains("recovery low")`, or that matches the three variants, to `CoachRules.recoveryChip(ctx.health.recovery?.score)`.
- **Routing check:** all three variants reach `recovery(q)` (:712). None of them matches an earlier route: "helped" is not "what helps", "affects" matches no plan word, and none contains "rem", "wake" or "deep". After B2, `focus()` sees "recovery" and drops any sheet metric.

### B4 · Empty gap above the first reply in the Coach sheet
**Root cause** (CoachConversation.swift:70): `.defaultScrollAnchor(engine.messages.isEmpty ? .top : .bottom)`. `CoachSheet.onAppear` calls `engine.start(about:)` (CoachViews.swift:159). That appends the opener at once, so the anchor becomes `.bottom`. A single short reply is shorter than the viewport, and a `.bottom` anchor **aligns short content to the bottom**, which leaves the empty band under the header. In the sheet the `intro` is empty after seeding (:223), so nothing fills the top.

**Patch.** Separate the alignment and initial-offset roles (iOS 18+), and fall back on iOS 17:
```swift
// CoachConversation.swift:70 → .chatScrollAnchor()
private extension View {
    @ViewBuilder func chatScrollAnchor() -> some View {
        if #available(iOS 18, *) {
            self.defaultScrollAnchor(.top, for: .alignment)        // short chat sits at the top
                .defaultScrollAnchor(.bottom, for: .initialOffset)  // long chat opens at the latest turn
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
        } else {
            self.defaultScrollAnchor(.top)                          // existing onChange → scrollDown handles growth
        }
    }
}
```
On iOS 17, also add `.onAppear { scrollDown(proxy, animated: false) }`. `scrollTo` on content that is shorter than the viewport is a no-op, so this does no harm. This change applies to both the Coach tab and the sheet, and it fixes both.

### B5 · "You tagged caffeine after 2 pm" listed as a cause of low SpO2
**Root cause:** `explain()` adds `c.tagsYesterday.sorted().first` (CoachRules.swift:881) for **any** metric of concern. It picks the alphabetically first tag, so "Alcohol" or "Caffeine…" usually wins. The same blind pattern appears in `recovery()` (:827) and `sleepWhy()` (:1026).

**Patch.** Use a metric-to-relevant-tags map, ordered by strength of link. Tags are from `JournalStore.defaultTags`:
```swift
// CoachRules.swift, inside Template
static let tagLinks: [MetricID: [String]] = [
    .restingHR:  ["Alcohol", "Feeling unwell", "Hard workout", "Stressful day", "Late meal", "Travel", "Caffeine after 2 pm"],
    .hrv:        ["Alcohol", "Feeling unwell", "Hard workout", "Stressful day", "Late meal", "Travel"],
    .sleepingHR: ["Alcohol", "Late meal", "Hard workout", "Feeling unwell", "Stressful day", "Caffeine after 2 pm"],
    .breathing:  ["Feeling unwell", "Alcohol", "Travel"],
    .spo2:       ["Alcohol", "Travel", "Feeling unwell"],            // altitude, congestion; NOT caffeine
    .skinTemp:   ["Feeling unwell", "Alcohol", "Late meal", "Travel", "Hard workout"],
    .sleepTotal: ["Caffeine after 2 pm", "Screen in bed", "Stressful day", "Alcohol", "Late meal", "Nap", "Travel"],
    .deepSleep:  ["Alcohol", "Late meal", "Caffeine after 2 pm", "Stressful day"],
    .remSleep:   ["Alcohol", "Caffeine after 2 pm", "Late meal", "Stressful day"],
    .awake:      ["Alcohol", "Caffeine after 2 pm", "Late meal", "Stressful day", "Screen in bed", "Nap"],
]
func linkedTag(for id: MetricID) -> String? {
    (Self.tagLinks[id] ?? []).first { c.tagsYesterday.contains($0) }
}
```
- **:881:** `if let tag = linkedTag(for: id) { sentences.append("You tagged \(tag.lowercased()) yesterday.") }`
- **:827:** use `linkedTag(for: main.id)` (the main drag), falling back to `linkedTag(for: .restingHR)`.
- **:1026:** use `linkedTag(for: .sleepTotal)`.
- Tags that don't match are left out, which follows the rule "never say a link we can't back".
- **Model path:** add one line to `instructions(ctx:)` (CoachEngine.swift:440): "Only mention a journal tag as a possible cause for the signals it can affect: caffeine for sleep and heart rate, never blood oxygen." Better still, have `getJournal` (CoachTools.swift:297) return the same map so the model sees which tags are linked.

### Side finding (not in the list)
`CoachNoteCard` chips only call `nav.openCoach(about: note.metric)` (CoachViews.swift:235). The chip text, e.g. "Plan an easy session", is never sent, so tapping a chip does the same thing as tapping the card. Fix: have `AppNav.openCoach(about:ask:)` seed and send the question. Do this only if it is in scope, because it touches Routes.swift.

## 3 · File ownership (no file owned twice)

| Builder | Owns (writes) | Work |
|---|---|---|
| **A · Today layout** | `MRH1/TodayView.swift`, `MRH1/TodayWeek.swift`, `MRH1/TodayCards.swift`, `MRH1/WeekViews.swift` | Reorder the modules; move `DayCircles` into Your week; update the comments and a11y hint; take the screenshots. No Coach logic: B1 needs **no** TodayView change once L2 has its cap. |
| **B · Coach rules** | `MRH1/Coach/CoachRules.swift`, `MRH1/Coach/CoachLibrary.swift` (read only unless the L3 cap needs a tweak) | B1 (L2/L3 caps, capReason, assert), B2 router + `static func focus(for:context:)` + `metricNamed(in:)`, B3 `recoveryChip(_:)` everywhere in the templates and starters, B5 `tagLinks` + `linkedTag`. |
| **C · Coach engine/UI + checks** | `MRH1/Coach/CoachEngine.swift`, `MRH1/Coach/UI/CoachConversation.swift`, `MRH1/Coach/CoachViews.swift`, `MRH1/Coach/UI/CoachSupport.swift`, `MRH1/Coach/CoachTools.swift`, a new `MRH1/Coach/CoachRulesChecks.swift` (DEBUG launch-arg self-test; the project uses a synchronized root group, so new files are picked up) | B2 engine side (`about = CoachRules.focus(...)`), B3 model-chip rewrite, B4 `chatScrollAnchor`, B5 model instruction / getJournal links, a scripted check for B1–B5. |

**Contract fixed before the builders start.** B publishes these signatures; C codes against them:
- `CoachRules.focus(for: String, context: MetricID?) -> MetricID?`
- `CoachRules.recoveryChip(_ score: Int?) -> String`

`TodayView` already calls `CoachRules.todayCap` and `Scores.todayStrainTarget`, and both keep their signatures.

Do not touch any of these unless the integrator decides to: `Routes.swift` (side finding), `Scores.swift`, `HealthStore.swift`, `Journal.swift`.
