# Wave 1 · v1.3 · Builder B (Coach rules)

Files I changed: `MRH1/Coach/CoachRules.swift` only. I read `CoachLibrary.swift` and did not need to change it.
Build: `build/B`, **BUILD SUCCEEDED**. xcodebuild needs the sandbox off because of CoreSimulator.

## Public API (DESIGN_SPEC_v1.3 §8)
```swift
enum Focus: Hashable { case recovery, sleep, strain, metric(MetricID), plan, week, general }  // top level
// also reachable as CoachRules.Focus (typealias)
extension CoachRules {   // all nonisolated (pure) unless noted
  static func focus(for text: String, context: MetricID?) -> Focus
  static func metricNamed(in text: String) -> MetricID?           // shared keyword map; "rem" whole word only
  static func recoveryChip(_ score: Int?) -> String
  static func relevantTags(for metric: MetricID?) -> Set<String>  // nil → all 10 default tags
  static func isRelevant(_ tag: String, for metric: MetricID?) -> Bool   // nil metric → true (custom tags too)
  static func linkedTag(in tagged: Set<String>, for metric: MetricID?) -> String?  // strongest relevant tag
  static var  recoveryTags: Set<String>
  static let  allTags: [String]                                    // mirror of JournalStore.defaultTags
  static func noteAdvisesEasing(_ note: CoachNote) -> Bool
  static func noteCapConflict(_ note: CoachNote?, cap: IntensityCap, target: ClosedRange<Double>) -> String?  // nil = OK
  #if DEBUG
  static func assertNoteMatchesCap(_ note: CoachNote?, cap: IntensityCap, target: ClosedRange<Double>)
  #endif
}
```
`todayCap(_:)` and `evaluate(_:journal:)` keep their signatures.

## What each fix does
- **B1**
  - L2 (load jump) now carries `cap: .easy`. L3 (Zone 3 heavy) carries `cap: .moderate`.
  - L3's note copy changed to fit that cap: "Keep your next session in Zones 1–2…" and the chip "Plan a Zone 2 session". It no longer says "truly easy", which would have sat under a 10–14 target.
  - `capReason` has new lines for L2 and L3.
  - The cap goes through `run()`, so `todayCap`, `evaluateCapOnly`, `evaluate().cap`, the verdict and StrainTargetCard all read the same cap.
  - `pickNote` now receives the cap. It skips the R4 "Green light: a hard session fits" note whenever the final cap is tighter than `.any`.
  - In DEBUG, `pickNote` calls `assertNoteMatchesCap`. A note that advises easing off (headline, body or chips matching ease in/off · go easy · keep … easy · easy session/day · truly easy · today is easy) must have a cap of `.easy` or tighter and a target upper bound of 8 or less. GENTLE notes are exempt because they show no target.
  - Mentions such as "yesterday was easy" or "an easy walk is fine" do not trip the assert.
- **B2**
  - The template router replaces `metric ?? mentionedMetric(q)` with a `switch focus(for:context:)`: `.metric` goes to `explain`, `.recovery` to `recovery(q)` and `.strain` to `hardness()`. `.sleep`, `.plan`, `.week` and `.general` fall through to the existing chain.
  - Precedence in `focus`: a metric named in the question, then recovery, strain, week, plan, sleep, then the chat's metric, then `.general`.
  - A sleep question inside a sleep-metric chat keeps that metric, so the v1.2 behaviour stays.
- **B3**
  - `recoveryChip` returns "Why is recovery low?" below 34, "What affects my recovery?" from 34 to 66, and "What helped recovery?" from 67 up. nil returns "What affects my recovery?".
  - It is now used in `starters` (which said "Why is recovery high?" before), `today()` (which said "high" at 63 %), the "what helps" branch of `recovery()`, the not-sent branch and default chips of `explain()`, and the no-plan case of `planReply`.
  - The red-only notes REST-LIMIT and R1 still hard-code "low"; that is correct because they only fire below 34.
  - Checked by script: all three phrasings route to `.recovery`, even with a sleepTotal or deepSleep context.
- **B5**
  - Tag links follow §5 and use the JournalStore ids:
    - Caffeine after 2 pm, Screen in bed, Late meal → sleep (total, deep, REM, awake), RHR, sleeping HR
    - Alcohol → those, plus SpO2 and breathing
    - Hard workout → RHR, HRV, workout minutes, energy
    - Stressful day, Travel → RHR, HRV, sleep
    - Feeling unwell → RHR, HRV, sleep, breathing, skin temp
    - Nap → sleep
    - Meditation → none
  - `explain`, `recovery` (the main drag, falling back to RHR) and `sleepWhy` now quote `linkedTag(...)` and no longer pick the alphabetically first tag.
  - The only SpO2 tag is Alcohol. Caffeine is never linked to SpO2 (checked by script).

## Open issues / notes for the integrator
- HRV stands in for "recovery" and workout minutes / energy stand in for "strain" in the tag map, because neither has a MetricID. Unwell → breathing / skin temp is my addition; §5 does not list it.
- `relevantTags(for: nil)` returns only the 10 default tags. Use `isRelevant(_:for:)` when custom tags must pass in the general case.
- `assertionFailure` stops DEBUG builds if a future note breaks B1. Release builds are unaffected.
- `metricNamed` still matches "last nights" → SpO2 and "wake" → awake. These quirks are from v1.2 and I left them.
