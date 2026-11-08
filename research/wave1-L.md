# Wave 1 · L · Coach engine, tools, models

Files (owned): `MRH1/Coach/CoachEngine.swift`, `MRH1/Coach/CoachTools.swift`, `MRH1/Coach/CoachModels.swift`.
Every §8 name and signature is kept; members were only added. No network code. FoundationModels is behind
`#if canImport(FoundationModels)` + `@available(iOS 26, *)`, so the iOS 17 target still builds.

## What was built

**CoachEngine** (`@Observable @MainActor final class`, no-arg `init()`)
- `mode`: `.onDevice` when `SystemLanguageModel.default` is available and `supportsLocale()` is true; otherwise
  `.rules(reason:)` with one plain line (iOS < 26, device not eligible, Apple Intelligence off, model downloading,
  unsupported language, AI chat switched off with UserDefaults `mrh1.coachAI = false`).
- `send(_:about:)`: appends the user message, then `CoachSafety.preCheck` (a non-nil reply is used and the model is never called).
  A crisis, emergency or minor category (`Category.endsCoaching`) pauses the model until `newChat()`, and every later
  message gets the same fixed copy. Rules mode always calls `CoachRules.templateReply`. On-device mode:
  - opens a `LanguageModelSession` with the 9 tools and short instructions (about 200 tokens: MRH1 voice, today's
    `CoachRules.evaluate` cap, the NotSent wording, banned words, reply in the user's language, style from UserDefaults
    `mrh1.coachStyle` = direct (default) / supportive / numbers, "sample data" in demo, plus a one-line summary seed);
  - streams a `@Generable CoachTurn` (headline, body, pills = metric ids ≤ 3, chips = exactly 3, planID) into the
    last coach message (`reply.isStreaming == true` while it streams);
  - maps the turn to `CoachReply`: headline clipped to 14 words, body to 3 sentences and 60 words, pills built in Swift
    from real `MetricState` values (never from model text; the asked-about metric is added if the model gave none),
    chips cleaned to exactly 3 of 2–4 words (defaults fill the gaps), and the plan only if `findSessions` returned it
    this chat (so it is within the cap);
  - runs `CoachSafety.postCheck(reply, allowedNumbers:)` against every number the tools and pills returned plus the
    user's own numbers. On failure it retries once ("use only tool numbers"), then falls back to `CoachRules.templateReply`;
  - adds `CoachSafety.modelGuidance(for:)` to the prompt when the message is in the `.condition` category;
  - errors: context overflow starts a new session seeded with a one-line summary and retries once. Guardrail or
    refusal gives the fixed `CoachEngine.decline`. Unsupported language switches `mode` to rules and gives a template
    reply. Anything else gives a template reply. Both `LanguageModelError` (iOS 27) and `GenerationError` (26.x) are handled;
  - the session restarts every 6 user turns, seeded with the summary, to stay inside the 4K window.
- `statusText` is real: each tool sets it ("Reading your last 7 nights…", "Reading your resting heart rate…",
  "Finding a session that fits today…", "Checking your signals…"). The fallback text is "Reading your data…".
  It is cleared when the reply text starts streaming. `isThinking` is true for the whole turn.
- `start(about:)` starts a new chat (the old one is archived) with an instant opener built from data, no model:
  value vs your normal, `MetricInfo.what`, early-read line, 1 pill, 3 metric chips. Passing nil starts a plain new chat.
- Demo (`Demo.isOn`): it runs on the demo HealthStore/JournalStore, every reply has `isSample = true`
  (label `CoachReply.sampleLabel` = "Sample data"), and nothing is written to disk.
- Transcripts are kept only on this iPhone, in `Application Support/Coach/transcripts.json`. The folder and file have
  `isExcludedFromBackup` set, with file protection `completeUntilFirstUserAuthentication`. Anything older than
  30 days is dropped at launch (`purgeOld()` is public too). A chat less than 12 h old resumes at launch, with the
  model session seeded by a summary; older chats move to `history`. `deleteAll()` wipes memory and the file.

**CoachTools** (`CoachToolContext`, a `@MainActor` class, plus 9 `Tool` structs and `CoachToolbox.all(ctx)`)
- The tools are `getToday`, `getMetric(metric, days)`, `getSleep(nights)`, `getLoad(days)`, `getSignals`,
  `getJournal(days)`, `getWeekly`, `getProfile` and `findSessions(kind, minutes, equipment)`. Each one is a `Sendable`
  struct holding the context and calling `await MainActor.run { ctx.<tool>() }`, so the model never queries HealthKit.
- Output is a compact `;`-separated string with pre-formatted numbers (MetricID.format, locale-aware). z-scores
  are given as words, not numbers.
- Every returned string goes into `ctx.numbers`, in several spellings (7,5 / 7.5 / 8, 4,210 / 4210), and this set is
  what goes to postCheck.
- `getMetric` for `hrv`, `skinTemp` or `vo2Max` always returns "Not sent by Google Health. Coach uses resting heart
  rate, breathing rate and sleep instead." Drivers for HRV and skin temperature are hidden in `getToday`.
- `findSessions` uses K's richer `CoachLibrary.find(cap:minutes:equipment:kind:avoid:age:limit:)` with today's cap.
  A "Feeling unwell" tag today or yesterday adds `avoid: ["unwell"]`. It returns at most 3 sessions and caches them for the reply's plan.
- The helpers are public for other agents: `ctx.pill(for: MetricID) -> DataPill?`,
  `CoachToolContext.shortName(_:)`, and `CoachToolContext.numbers(in:)` (nonisolated).

**CoachModels**
- `CoachReply`, `CoachMessage`, `DataPill` are now `Codable` + `Hashable`. DataPill stores its tier and metric as strings,
  through extensions on my own types only; Theme.swift and Metrics.swift are untouched.
- Added: `CoachReply.isSample`, `CoachReply.isStreaming`, `CoachReply.sampleLabel`; `CoachMessage.metric`, a full
  memberwise init with defaults, and `.user(_:about:)` / `.coach(_:)`; a new `CoachChat` (id, started, messages,
  lastActivity, title); `CoachProfile.saved` (UserDefaults `mrh1.coachProfile`), `save()`, `clear()`, `isEmpty`.

## Exact public API (engine)

```swift
@Observable @MainActor final class CoachEngine {
  enum Mode: Equatable { case onDevice, rules(reason: String) }
  var messages: [CoachMessage]; var isThinking: Bool; var statusText: String?; var mode: Mode
  private(set) var history: [CoachChat]        // past chats, newest first (current excluded)
  private(set) var focusMetric: MetricID?
  var isSample: Bool; var isConfigured: Bool; var isOnDevice: Bool
  var starters: [String]                        // CoachRules.starters(health:) or defaults
  static let aiEnabledKey = "mrh1.coachAI", styleKey = "mrh1.coachStyle", retentionDays = 30, turnsPerSession = 6
  static let decline: CoachReply; static let defaultChips: [String]
  init()
  func configure(health: HealthStore, journal: JournalStore)   // O: call once; safe to call again
  func refreshMode()                                           // call on foreground / after the AI toggle
  func prewarm()
  func send(_ text: String, about metric: MetricID? = nil) async
  func start(about metric: MetricID?)
  func newChat(); func open(_ chat: CoachChat); func deleteAll(); func purgeOld()
  static func cleanChips(_:maxWords:) -> [String]; static func chips(for:state:) -> [String]
}
```

## Open issues / notes for others
- **O**: call `engine.configure(health:journal:)` after the stores exist, and `refreshMode()` on scenePhase `.active`.
  The Menu "AI chat" toggle (if added) should write `UserDefaults` `mrh1.coachAI`, and Style should write `mrh1.coachStyle`
  ("direct" / "supportive" / "numbers"). Onboarding saves its answers with `CoachProfile(...).save()`.
- **N**: while `reply.isStreaming`, hide chips and pills (numbers never stream) and show `statusText` while
  `headline` is empty. Show `CoachReply.sampleLabel` when `reply.isSample`. `history` and `open(_:)` back the History menu.
- I could not test the on-device model in this sandbox, because the simulator runtime is unavailable to the agent. Prompt and
  guide behaviour (chip lengths, pill ids, planID) needs a device pass on iOS 27 with the golden set (research v11-02 §10).
- K's `templateReply` chips can be up to 6 words (only the count is enforced on template replies). Model chips are held to ≤ 4 words.
- `CoachSafety.postCheck` also checks pills and plans, so pill numbers are added to the allowed set when the pills are built.
