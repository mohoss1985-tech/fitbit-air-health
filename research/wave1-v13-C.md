# Wave 1 · v1.3 · C — Coach engine + screens

Builds: `build/C` (generic iOS) **BUILD SUCCEEDED**, `build/Csim` (iPhone 18 Pro sim, iOS 27.2) BUILD SUCCEEDED.
Self-test: `-demo -runChecks -coachSkipIntro` on the simulator → 29 checks, **CHECK ALL PASSED**.

## What was built
- **B2 (engine)** `CoachEngine.send` now calls `CoachRules.focus(for:context:)` on (`metric ?? focusMetric`).
  The turn's metric comes from `focusedMetric(_:context:)`: `.metric(m)` → m, `.sleep` keeps a sleep chat's metric
  (or nil), `.general` keeps the context, recovery/strain/plan/week → nil. That metric goes to the template, the
  model, and the pill fallback. The model prompt also gets the topic (`prompt(_:metric:topic:)` → "about recovery").
  The chat's `focusMetric` (the sheet's metric) is unchanged, so later generic questions still use it.
- **B3** `CoachEngine.fixRecoveryChips(_:score:)` rewrites any chip that names a recovery direction (low/high/up/down/
  poor/good/red/green) to `CoachRules.recoveryChip(score)` and removes duplicates. It runs on model chips (`map`) and
  template chips (`template`). Coach tab starters (`CoachStarterSource.make` and `fallback`) use it too.
- **B4** `CoachConversation` uses `.chatScrollAnchor()`. On iOS 18+ that is `.defaultScrollAnchor(.top, for: .alignment)`,
  `.bottom` for `.initialOffset` and `.bottom` for `.sizeChanges`. On iOS 17 it is `.top`, plus `scrollDown` on appear.
  Tab-reselect scroll-to-top (`nav.scrollTopTick[.coach]`) and the left-edge back swipe are unchanged.
- **B5** `CoachToolContext.setFocus(metric:allowedTags:)` runs per turn. `getJournal` lists only allowed tags, says
  that the others were left out, and drops discoveries that name a blocked tag. When a metric is a concern,
  `getMetric` lists "journal tags that can affect this". Allowed tags: metric → `relevantTags(for:)`, sleep →
  `.sleepTotal`, recovery → `CoachRules.recoveryTags`, otherwise all. New model instruction line: "Never link a journal tag
  to a metric it doesn't affect (caffeine never explains blood oxygen). Only cite tags getJournal lists."
- **Coach note chips send**: `CoachNoteCard` chips call `nav.openCoach(about: note.metric, asking: chip)`.
  - The sheet takes the prompt in `onAppear`, seeds without the opener and sends the question once.
  - The tab sends it when the Coach tab is showing and no sheet is up: it starts a fresh chat, then sends.
  - Coach off: nothing is queued and `takeCoachPrompt()` returns nil.
- **CoachRulesChecks.swift** (DEBUG only). `-runChecks` runs it from the `ContentView` `.task` and prints `CHECK PASS/FAIL …`
  and then `CHECK ALL PASSED` / `CHECK n FAILED`.

## Public API (new / changed)
```swift
// Routes.swift · AppNav
var coachPrompt: String?
func openCoach(about metric: MetricID?, asking question: String?)   // old openCoach(about:) unchanged
func takeCoachPrompt() -> String?                                    // returns + clears; nil when Coach off
// CoachEngine
func start(about metric: MetricID?, opener: Bool = true)
static func focusedMetric(_ focus: Focus, context: MetricID?) -> MetricID?
static func focusedMetric(for question: String, context: MetricID?) -> MetricID?
static func topicName(_ focus: Focus) -> String?
static func allowedTags(_ focus: Focus, metric: MetricID?) -> Set<String>?
static func fixRecoveryChips(_ chips: [String], score: Int?) -> [String]
static func prompt(_ question: String, metric: MetricID?, topic: String?) -> String   // 2-arg kept
// CoachToolContext
private(set) var focusMetric: MetricID?; private(set) var allowedTags: Set<String>?
func setFocus(metric: MetricID?, allowedTags: Set<String>?)
// CoachConversation
init(context: CoachContext, prompt: String? = nil)
// CoachRulesChecks (DEBUG)
static func run(health: HealthStore, journal: JournalStore, log: ((String) -> Void)? = nil) -> [String]
```

## Open issues
- B4 is checked in code only. I took no screenshot of the CoachSheet: a CoachMark tap is needed, and no launch argument opens a sheet about a metric.
- If a reply is still streaming when a note-chip prompt reaches the Coach tab, `engine.send` refuses it while
  `isThinking` is true, and the prompt is lost. This edge case is rare.
- During the run, `-runChecks` briefly overrides `health.recovery` (63), `states[.workoutMinutes]` and (demo only) yesterday's
  caffeine tag, then restores them. It uses `CoachRules.signals` and not `evaluate`, so no note memory is written.
- `fixRecoveryChips` is a second safety net. B's `CoachRules.starters` and templates already use `recoveryChip`.
