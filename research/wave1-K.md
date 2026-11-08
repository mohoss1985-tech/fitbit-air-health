# Wave 1 · K — Coach rules + workout library

Files: `MRH1/Coach/CoachRules.swift`, `MRH1/Coach/CoachLibrary.swift`, `MRH1/Coach/CoachLibrary.json` (new, auto-bundled by the synchronized group; verified in `MRH1.app/`). Build `build/K`: **BUILD SUCCEEDED**. No network code, no edits outside these files.

## Public API

```swift
// CoachRules.swift  (@MainActor enum)
static func evaluate(_ health: HealthStore, journal: JournalStore) -> CoachRuleResult   // fired ids, hard cap, Today note
static func signals(_ health: HealthStore, journal: JournalStore) -> [CoachSignal]      // for getSignals: id, text, metrics, cap
static func templateReply(for question: String, metric: MetricID?, health: HealthStore, journal: JournalStore) -> CoachReply
static func starters(health: HealthStore) -> [String]     // 4: Recovery, Sleep, Strain, Plan
static func isImportant(_ note: CoachNote) -> Bool        // Watch/rest notes ("Important only")
static func resetMemory()                                 // call from "Delete coach history"
static func cleanChips(_:) / limitWords(_:_:) / fitBody(headline:body:limit:) / words(_:)   // copy helpers
struct CoachSignal { id, text, metrics: [MetricID], cap: IntensityCap? }

// CoachLibrary.swift
extension IntensityCap { libraryRank, capped(at:), plainWord, maxMinutes (rest 30, easy 45, moderate 120, any 150) }
static func find(cap: IntensityCap, minutes: Int, equipment: String?) -> [CoachPlan]   // contract; all matches, best first, first 3 different kinds
static func find(cap:minutes:equipment:kind:focus:maxZone:avoid:indoorOnly:age:limit:) -> [CoachPlan]
static func plan(_ s: Session, minutes: Int, age: Int?) -> CoachPlan
static let sessions: [Session]; static func session(id:) -> Session?
static func zonesBPM(age:) -> [ClosedRange<Int>]; zoneText(_:maxHR:); patternText(_:); allowedGear(_:)
static let safetyCue = "Stop if you feel pain or dizziness."
```
`CoachPlan.id` is the session id (no minutes suffix), so L's `plan(id:)` lookup works.

## Rules (stable ids in `fired`)
- **Readiness:** R1 (red + debt >300 min → rest), R2 (red → easy), R3 (34–66 → moderate), R4 (≥67, no hard day yesterday → any; else moderate), R5 (2 hard days ≥14 → easy), R6 (strain ≥ target top → rest-level: cool-down or walk), R7 (no score → moderate + "Early read").
- **Rest limits (§5):** rest only on red recovery (R1, or W2 when red) or **REST-DEBT** (debt ≥2 h and strain above target). Rest days are stored per day. If the 2 days before were rest days → **REST-LIMIT**: cap easy and the copy offers light movement.
- **Watch:** W1 (RHR ≥ mean+5 on 2 consecutive nights, mean leaves out those 2) → easy. W2 (W1 + breathing ≥ baseline+1.0) → "2 signals are outside your usual range". W3 (SpO2 <93 on ≥3/7 nights, or any night <90 → "see a doctor"; no cap). W4 (tag Feeling unwell/sick, today or yesterday → neck check, cap rest). W5 (≥3 hours at stress level ≥2).
- **Sleep:** S-a (<7 h; ≤6 h caps easy), S-b (spread >45 min), S-c (caffeine discovery or tag + lower score → 8 h cut-off from usual bedtime), S-d (deep/REM below range after Alcohol/Late meal), S-e (debt >300).
- **Load:** L1 (<150 → minutes to go; ≥300 → praise + recovery), L2 (7-day minutes ÷ mean of 4 prior weeks >1.5, soft wording), L3 (today: Zone 3 > Zones 1–2 on a training day), L4 (see open issues), L5 (yesterday's steps <5,000; goal 8–10k, or 6–8k at 60+).
- **GENTLE:** tags travel/vacation/holiday/sick → cap moderate, no strain targets, L1/L2/L4/L5/R4 notes off.
- **Note selection:** a priority order per slot (morning / within 3 h after a workout / from 20:00). Repetition guard: the same observation at most once in 3 days, kept steady on the day it is raised. At most 3 different notes a day. Notes are only built for rules that add an action or a multi-day or tag pattern. R2, R3, R6 and R7 would only restate the verdict, so they get no note. Headline ≤14 words, total ≤40 (trailing sentences trimmed), exactly 3 chips of ≤4 words. `UserDefaults "coach.proactive"`: off → nil; important → only W1–W4/R1/R5/REST-* notes; daily (default) → morning card, kept all day; every → all 3 slots.

## Template coach
Routes by keyword: What can you see · unwell (neck check) · rest day / wind-down / breathing / mobility (plans) · plan my week · weekly review · training too much · zones (bpm table) · plan/workout (minutes parsed from "20 min", shorter/longer/easier/indoor/dumbbell/hard) · nap · sleep debt · caffeine · bedtime regularity · metric explain (E1: value vs your normal, ≤2 causes from `ifHigh`/`ifLow` only when it is a concern, yesterday's tag, NotSent wording) · sleep better / why sleep was poor · recovery (E1 on the contributor with the most negative z, "is this a concern", "what helps") · strain / how hard · steps · tags · stress · today summary.
DataPills come from real `MetricState` values ("RHR 58 · normal 54–57" + tier). `isTemplate = true`, `isSample = health.isDemo`. Chips go through `cleanChips`: exactly 3, each ≤4 words. Every chip literal was checked.

## Library (63 sessions)
- 16 strength (bodyweight A/B, starter, core, balance, legs, upper, intervals; dumbbell light, full A/B, upper, lower, circuit; gym machines).
- 12 mobility/stretch, 6 breathing, 3 wind-down, 1 rest-day routine.
- 6 walks, 9 runs (incl. 3 interval sessions), 6 rides, 1 row, 3 other cardio (elliptical, indoor no-gear, swim).
- Intensity: 26 rest, 15 easy, 15 moderate, 7 any.

Each session has id/name/kind/intensity/modes/minutes/zones/strainEstimate/recoveryMin/equipment/indoor/focus/summary/steps/avoidIf/source.

**Schema deviation:** `"minutes":"rest"` became `"fill": true`. Steps scale like this:
- fixed `minutes` steps keep their length;
- the `fill` step takes the remaining time;
- strength sets scale from the base count up to base+2 (6 at most);
- breathing rounds scale (3 at least).

Zones are rendered in bpm from 208 − 0.7·age, or 185 when age is unknown. The safety cue is added in code to every plan's last step. A standalone harness confirmed: plans land within ±25 % of the requested minutes for all 63 sessions × 3 lengths, and every plan ends with the cue.

## Open issues
- **L4** cannot be exact: HealthStore only keeps workout *names* for today, so L4 fires only when no workouts were logged in 7 days. A `workouts7d` list in HealthStore would fix it.
- **L3** uses today's zone minutes only. There is no 7-day zone history.
- Rest-day streak, the repetition guard and the daily note count live in UserDefaults (`mrh1.coach.restDays`, `mrh1.coach.noteShown`, `mrh1.coach.dayNotes`; in memory in demo mode). They are recorded on `evaluate`, not on view, so a note counts as shown once it is selected.
- Rule output on demo data was not checked in the Simulator: the console capture returned nothing, so the debug dump was removed. Logic was reviewed by hand. M's XCTest suite or a manual demo run should check the Today note copy.
- The 5-word starters from the research table were shortened ("Why was sleep poor?", "How hard today?"). Routing still accepts the long forms.
