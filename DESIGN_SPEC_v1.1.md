# DESIGN_SPEC v1.1 · Coach (addendum to DESIGN_SPEC.md)

`DESIGN_SPEC.md` (v1.0) still rules tokens, type, motion, copy and every existing screen. This file only adds the
coach. Where the two disagree on coach matters, this file wins. Sources: `research/v11-01…05`.

## 0 · Identity in one line
A quiet, free coach that lives on your iPhone, explains your own numbers in a few words, and always offers the next
3 questions — never a wall of text, never a made-up workout, never a diagnosis.

## 1 · Conflicts resolved (owner decisions 2026-11-07 marked ★)

| Topic | Reports said | Decision |
|---|---|---|
| Where it lives | 01: sheet, keep 4 tabs · 03: 5th tab | ★ **5th tab "Coach"** + a small **CoachMark** on every data card + "Ask about this" in sheets |
| Floating button | 01: Google-style FAB on every tab | ★ No FAB. The CoachMark is the "floating" entry: small, gentle, next to the ⓘ |
| Engine | all: on-device | ★ **Apple Foundation Models on-device only.** No cloud, no network code. Free. |
| Price | 01: one-time unlock | ★ **Free**, no paywall |
| Workout output | 01: checkbox card · 03: full runner | PlanCard with checkboxes **and** an optional step timer (PlanRunner). No video. |
| Chat history | 02: none across launches · 04: 30 days | Transcripts kept **on device 30 days** (excluded from backup); the model session restarts each launch, seeded with a 1-line summary |
| Tools | 02: 5 · 05: 9 | 9 tools (§8), compact output |
| Reply length | 01: 60 words · 02: 90 | Chat ≤ 60 words (hard cap 150 with "More detail"); Today card ≤ 40 words |

## 2 · Tokens (new, built from v1.0 tokens only)
- `UserBubble`: fill `Theme.ink`, text `Theme.paper`, radius 16, padding 12 h / 8 v, max width 78%, no tail.
- Coach reply: unboxed `.body` text in `Theme.ink`; headline `.headline` ≤ 14 words.
- `SuggestionChip`: capsule, 36 pt visual / 44 pt hit, `.label`, `Theme.hair` 0.5 stroke, `Theme.ink` text.
- `DataPill`: "RHR 58 · normal 54–57", `.label` monospaced digits, status-tier dot (green/yellow/red) — same colours as StatusChip.
- Spacing: 24 between turns, 12 inside a turn. Footer caption `.caption` `Theme.graphite`.
- **No new colours. No sparkles, no robot, no avatar, no emoji, no exclamation marks.**

## 3 · Signature graphic: the CoachMark (owner: "do it like a speech bubble")
The coach's single recognisable symbol, used everywhere it appears (tab icon, CoachMark, thinking state):
**a small rounded speech bubble (custom `CoachBubbleShape`: rounded rect, radius ~35% of height, short tail bottom-left),
outline only, with a solid ember dot in its centre.**
- **CoachMark** (on data cards): 16 pt, 1.25 pt stroke in `Theme.graphite2`, ember dot at 60% opacity, 44 pt hit area,
  top-right of a card / row, to the right of the ⓘ if present. Press: stroke brightens to `Theme.ink` (Motion.press).
  Tap → `CoachSheet` seeded with that metric ("Ask about Resting heart rate"). VoiceOver: "Ask Coach about <metric>".
- **Tab icon:** same bubble at tab size; selected = ink stroke + full ember dot.
- **Thinking:** inside the bubble the dot becomes 3 dots that pulse in turn (Motion.tick), with real status text from
  the tool being called ("Reading your last 7 nights…"). Reduce Motion: static 3 dots + text.
- Not SF Symbols `sparkles`, no robot, no avatar.

## 4 · Information architecture
Tabs: Today · Live · Body · Trends · **Coach**.
1. **Coach tab (`CoachView`)**: greeting sentence with today's numbers → 4 data-generated starter rows (Recovery, Sleep,
   Strain, Plan) → conversation → composer (grows to 5 lines, dictation never auto-sends). Header: "Coach" + menu (…):
   New chat · History · What Coach knows · Settings.
2. **CoachMark** on: Today rings & cards, Live chart card, every Body ResultRow, every Trends change card.
3. **"Ask about this" row** at the foot of every ScoreDetail and MetricSheet.
4. **`CoachNoteCard` on Today** under the freshness chips: rule-based (no model), ≤ 40 words, one action, 1 at a time,
   max 3 a day (morning / after workout / evening), collapsible, skipped if it would only restate a chart.
   Tap → Coach tab with that note threaded.
5. **Menu → Coach section:** Coach on/off (off = exact v1.0 app) · Proactive notes: Off / Important only / Daily (default)
   / Every moment · Style: Direct (default) / Supportive / Numbers only · What Coach knows · Delete coach history.
6. **First open (≤ 60 s, skippable):** "What Coach can see" screen (data list, "processed on this iPhone") + 18+ confirm →
   4 chip questions: goal · active days a week · equipment · limits.

## 5 · Copy rules (in addition to v1.0 §5)
- Every reply: headline ≤ 14 words, ≤ 3 sentences, 1–3 DataPills, **exactly 3 chips**, each a full standalone question
  ≤ 4 words ("Why is RHR up?", never "Yes" / "Tonight").
- Numbers only from tool results; a validator rejects any other number (1 retry, then template reply).
- Missing data uses the NotSent wording ("Not sent by Google Health") + what the coach uses instead.
- Rest is suggested only on red Recovery, or sleep debt ≥ 2 h with Strain above target; never more than 2 days running.
- Low days are "recovery day", never "below target". No calorie or weight targets. No injury talk.
- Banned in output (filter): diagnose, detect, apnea, AFib, hypoxia, arrhythmia, abnormal, danger, dose, mg.
- Footer on every coach screen: "AI coach on this iPhone · can be wrong · wellness, not medical advice."
- Intended purpose (store, onboarding, policy): "MRH1 Coach gives general wellness and fitness suggestions based on your
  own Apple Health data. It is not a medical device and does not diagnose, treat or prevent any condition. Check with a
  doctor before making health decisions."

## 6 · Motion
Streamed text fades in by chunk (160 ms). Cards enter with `Motion.enter`. Chips appear only after the reply ends
(stagger 40 ms). Numbers never stream. Haptic `.selection` on chip tap, `.success` on plan step done. Reduce Motion:
opacity only.

## 7 · Demo mode & fallback
- Demo: the coach runs on demo data, replies labelled "Sample data" — App Review can test every skill without a band.
- **Rule-based coach** (same UI, template replies from `CoachRules` + `Insights`) when: iOS < 26, no Apple Intelligence,
  AI switched off, model downloading, unsupported language. One plain line says why (+ Settings hint).

## 8 · Shared API contract (names FIXED)
```swift
// CoachRules.swift — pure Swift, no model
enum IntensityCap { case rest, easy, moderate, any }
struct CoachRuleResult { let fired: [String]; let cap: IntensityCap; let note: CoachNote? }
enum CoachRules { static func evaluate(_ health: HealthStore, journal: JournalStore) -> CoachRuleResult }
struct CoachNote: Identifiable { let id: String; let headline: String; let body: String; let metric: MetricID?; let chips: [String] }

// CoachModels.swift
struct DataPill: Hashable { let metric: MetricID; let text: String; let tier: StatusTier? }
struct CoachReply { var headline: String; var body: String; var pills: [DataPill]; var chips: [String]; var plan: CoachPlan?; var isTemplate: Bool }
struct CoachPlan: Identifiable, Codable { let id: String; let title: String; let minutes: Int; let steps: [PlanStep] }
struct PlanStep: Codable, Hashable { let name: String; let seconds: Int?; let reps: String?; let cue: String }
struct CoachMessage: Identifiable, Codable { let id: UUID; let role: Role; let date: Date; var reply: CoachReply?; var text: String?; enum Role: String, Codable { case user, coach } }
struct CoachProfile: Codable { var goal: String?; var daysPerWeek: Int?; var equipment: String?; var limits: String? }

// CoachEngine.swift — @Observable @MainActor
final class CoachEngine { var messages: [CoachMessage]; var isThinking: Bool; var statusText: String?; var mode: Mode
  enum Mode { case onDevice, rules(reason: String) }
  func send(_ text: String, about metric: MetricID? = nil) async
  func start(about metric: MetricID?)   // seeds a chat from CoachMark / Ask about this
  func newChat(); func deleteAll() }

// CoachTools.swift — 9 read-only tools: getToday, getMetric, getSleep, getLoad, getSignals, getJournal, getWeekly, getProfile, findSessions
// CoachSafety.swift — static func preCheck(_ text: String) -> CoachReply?  (emergency / crisis / medical, fixed copy, localised)
//                     static func postCheck(_ reply: CoachReply, allowedNumbers: Set<String>) -> Bool
// CoachLibrary.json + CoachLibrary.swift — ~60 reviewed sessions; static func find(cap: IntensityCap, minutes: Int, equipment: String?) -> [CoachPlan]
// UI: CoachView (tab), CoachSheet, CoachMark(metric:), CoachNoteCard, SuggestionChip, UserBubble, DataPillView, PlanCard, PlanRunnerView, CoachThinking
// AppNav gains: case coach tab; func openCoach(about: MetricID?)
```

## 9 · Parallel build rules
- File owners (Wave 1): **K** CoachRules + CoachLibrary (+ JSON) · **L** CoachEngine + CoachTools + CoachModels (FoundationModels,
  `#if canImport` + `@available(iOS 26, *)`, iOS 17 target kept) · **M** CoachSafety + XCTest risky-prompt suite ·
  **N** Coach UI (CoachView, CoachSheet, chips, bubbles, pills, PlanCard/Runner, thinking) · **O** integration: 5th tab,
  CoachMark on Today/Live/Body/Trends, Ask-about rows, CoachNoteCard, Menu section, onboarding, demo mode.
- L lands §8 names compiling first (≈ 10 min); others code against §8. Each agent builds into `build/<LETTER>`.
- Never remove v1.0 features. Coach off = v1.0 exactly.
