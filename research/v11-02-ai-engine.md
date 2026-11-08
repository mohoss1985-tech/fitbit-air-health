# v1.1 research 02 · AI engine for the coach

Researched 2026-11-07. The question: which model should run MRH1's coach (chat, tappable replies, proactive tips), given the v1.0 promise "no internet code, nothing leaves the phone", App Store health rules, and near-zero running cost.

## Sources

Apple, primary:
- Foundation Models updates (Feb 2026 = iOS 26.4, Jun 2026 = iOS 27): https://developer.apple.com/documentation/updates/foundationmodels
- `SystemLanguageModel.contextSize` (back-deployed to 26.4): https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize
- `SystemLanguageModel.Availability`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum
- `Tool` protocol: https://developer.apple.com/documentation/foundationmodels/tool
- `streamResponse(to:options:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse(to:options:)
- `LanguageModelError` (iOS 27; `GenerationError` deprecated after 26.x): https://developer.apple.com/documentation/foundationmodels/languagemodelerror and https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror
- `PrivateCloudComputeLanguageModel` (iOS 27): https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel
- Private Cloud Compute for developers (eligibility, cost, quotas): https://developer.apple.com/private-cloud-compute/
- Acceptable use requirements for Foundation Models: https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/
- Apple Intelligence devices, languages, regions: https://support.apple.com/en-us/121115
- App Review Guidelines 1.4.1, 5.1.2(i), 5.1.3: https://developer.apple.com/app-store/review/guidelines/
- Apple Foundation Models tech report 2025 (~3B on-device model): https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025

Secondary (confirm before relying on them):
- WWDC26 recap: 8,192-token on-device window, PCC 32K, reasoning levels, Claude/Gemini `LanguageModel` packages: https://dev.to/hariharanjagan/whats-new-in-apples-foundation-models-framework-at-wwdc-2026-5227
- About 30 tok/s on iPhone 17 Pro, cloud providers behind the same API: https://ai2.work/blog/apple-opens-its-foundation-models-framework-to-cloud-ai-providers
- Context window management (4,096 in 26.x): https://infoq.com/news/2026/03/apple-foundation-models-context
- Gemini Flash pricing, October 2026: https://www.morphllm.com/gemini-api-pricing

Anthropic: model IDs and prices come from the Claude API reference (claude-api skill, cached 2026-10-06; live page: https://platform.claude.com/docs/en/about-claude/pricing).

## Findings

### What the Apple frameworks offer today

- **On-device model** (`SystemLanguageModel`). About 3B parameters. Apple updated it in iOS 26.4 (better instruction following and tool calling, fewer false guardrail blocks) and again in iOS 27 ("follows instructions more accurately… complex scenarios"). Each OS update changes the model, so prompts must be re-tested every release.
- **Context window.** 4,096 tokens on 26.x, counting prompt and output together. A secondary source reports 8,192 on iOS 27. Read `contextSize` at runtime and measure with `tokenCount(for:)`. Don't hard-code either number.
- **Building blocks**: guided generation (`@Generable`/`@Guide` with `.anyOf`, `.count`, `.range`), tool calling (the `Tool` protocol, with a `ToolCallingMode` option added in iOS 27), streaming snapshots, and `prewarm()`. iOS 27 also adds image input, `DynamicProfile`, `response.usage`, and a richer Instruments template.
- **Devices.** It needs Apple Intelligence hardware: iPhone 15 Pro and later, 16, 17, Air, Duo. Plain iPhone 15/14/13 and older can't run it, and many MRH1 buyers will own one of those. Apple Intelligence must also be switched on and the model downloaded (`.unavailable(.deviceNotEligible / .appleIntelligenceNotEnabled / .modelNotReady)`). It doesn't work in mainland China.
- **Languages**: EN, DA, NL, FR, DE, IT, NO, PT, ES, SV, TR, VI, ZH-Hans, ZH-Hant, JA, KO. That covers MRH1's likely markets. Other languages throw `unsupportedLanguageOrLocale`.
- **Health limits.** The acceptable-use rules forbid "inaccurate or dangerous outputs… in high-risk domains, including… medical", along with self-harm content and "dependency or spiraling" interactions. Guardrails can throw `guardrailViolation` or `refusal` on sensitive health wording, so the UI needs a polite fallback. Wellness coaching on the user's own numbers is fine. Diagnosis is not.
- **Background work.** Apple says to use non-streaming `respond` in the background to avoid `rateLimited`. Proactive tips should be generated at foreground refresh time, not from background tasks.
- **Cost and battery.** No per-token cost. Short replies run on the Neural Engine and cost little battery when answers stay under about 200 tokens. There is no published per-token energy figure.

### Private Cloud Compute (`PrivateCloudComputeLanguageModel`, iOS 27)

- Same API. Bigger context (secondary source: 32K), configurable reasoning.
- **Free** for Small Business Program developers with fewer than 2M first-time downloads, subject to daily quotas (`quotaUsage`) and a managed entitlement.
- **It is a network call**, but to Apple's attested PCC servers, not a third party. Fees may come later. Above 2M downloads you must migrate off it within 6 months.

### Cloud LLMs

- They need a server-side proxy to hold the API key (a key shipped in the app gets extracted). That means infrastructure, ongoing cost, and **real "internet code"**.
- **5.1.2(i)**: "clearly disclose where personal data will be shared with third parties, **including with third-party AI**, and obtain explicit permission". **5.1.3(i)** bars using health data for anything beyond health management and requires permission. A per-feature consent screen and new privacy-label entries (Health & Fitness data, linked) are required.

### Comparison

| | Apple on-device (FM) | Apple PCC | Claude API | Gemini API |
|---|---|---|---|---|
| Models | ~3B system model | Apple server model | `claude-haiku-5-5`, `claude-sonnet-5-5`, `claude-opus-5-5` | 3.6 / 3.8 Flash |
| Context | 4K (26.x), ~8K? (27) | ~32K (secondary) | 1M | 1M |
| Quality for coaching | OK for short, grounded replies over tool data. Weak on long reasoning and plans | Better | Haiku good, Sonnet excellent | Good |
| Tools / structured output | Yes (`Tool`, `@Generable`) | Yes, same API | Yes (tool use, strict schemas) | Yes |
| Streaming | Yes | Yes | Yes | Yes |
| Devices | AI-capable iPhones, iOS 26+ | AI-capable iPhones, iOS 27+ | Any | Any |
| Offline | Yes | No | No | No |
| Data leaves phone | **No** | To Apple PCC (attested, not stored) | Yes, third party | Yes, third party |
| v1.0 promise | Kept | Bent (needs a disclosure) | Broken | Broken |
| App Review | Plain | Plain + entitlement | 5.1.2(i) consent + label | Same |
| Cost per user/month* | $0 | $0 now (quota, may get fees) | Haiku ≈ $0.35; Sonnet ≈ $4–7 | ≈ $2.5 |
| Owner effort | Swift only | Swift + entitlement request | Swift + proxy backend + key mgmt | Same |

*Cost model: a realistic engaged user has about 12 chat turns a day plus 1 proactive tip, so ~390 calls a month. Each call averages ~7K input tokens (instructions, tools, history, tool results, including tool-loop round trips) and ~350 output tokens, for ~2.7M input and ~0.14M output a month.
- Haiku 5.5 ($0.10/$0.50 per MTok): about $0.27 + $0.07 ≈ **$0.35**.
- Sonnet 5.5 ($2/$10): $5.46 + $1.37 ≈ $6.8, or ~$4 with prompt caching (cache reads $0.20/MTok).
- Opus 5.5 ($4/$20): ~2× Sonnet.
- Gemini Flash ($0.75/$3.75): ~$2.5.
- Heavy users run ~3×. Add the proxy hosting cost (~$5–20/month flat at small scale).

### What it means for MRH1

The coach's value comes from **MRH1's own computed numbers** (Recovery, Strain vs target, sleep debt, trends vs "your normal"). The model only has to explain them and pick next steps. That suits a small model fed by tools, which keeps payloads small enough for 4K. Long training plans are where a small model falls short. That's why an optional "deeper answer" path is worth having, but it shouldn't ship in v1.1.

## Draft code

Target: MRH1 deploys to iOS 17. Everything here is gated `@available(iOS 26, *)`. The coach tab shows the rule-based fallback on unsupported setups. Tool names follow the real `HealthStore` / `MetricState` / `Insights` / `Scores` APIs.

```swift
// CoachEngine.swift — on-device only. No network code.
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Tools (read-only views over HealthStore; outputs are short strings to save context)

@available(iOS 26, *)
struct GetTodayScoresTool: Tool {
    let health: HealthStore            // @MainActor class → Sendable
    let name = "getTodayScores"
    let description = "Today's Recovery (0-100), Strain (0-21) with today's strain target, and last night's Sleep score."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let t = Scores.strainTarget(health.recovery)
            var s = "recovery=\(health.recovery.map { "\($0.score)%" } ?? "none")"
            s += "; strain=\(health.strain.map { String(format: "%.1f", $0.value) } ?? "none")"
            s += "; strainTarget=\(Int(t.lowerBound))-\(Int(t.upperBound))"
            s += "; sleepScore=\(health.sleepScore.map(String.init) ?? "none")"
            if let r = health.recovery {
                s += "; drivers=" + r.contributors.map { "\($0.label) \($0.valueText) z\(String(format: "%+.1f", $0.z))" }.joined(separator: ", ")
            }
            return s
        }
    }
}

@available(iOS 26, *)
struct GetMetricStateTool: Tool {
    let health: HealthStore
    let name = "getMetricState"
    let description = "One metric vs the user's 30-day normal: latest value, usual range, direction, 7-day trend."
    @Generable struct Arguments {
        @Guide(description: "Metric id", .anyOf(MetricID.allCases.filter { !$0.isNotSentByGoogle }.map(\.rawValue)))
        var metric: String
    }
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            guard let id = MetricID(rawValue: arguments.metric) else { return "unknown metric" }
            let s = health.state(id)
            if let m = s.missing { return "\(id.info.name): \(m.text)" }
            var out = "\(id.info.name): \(s.valueText) \(id.info.unit); usual \(s.yourRangeText); \(s.flag.directionWord)"
            if s.isConcern { out += " (concern)" }
            if let e = s.earlyReadText { out += "; \(e)" }
            if let tr = Insights.trend(s) { out += "; \(tr.sentence)" }
            return out
        }
    }
}

@available(iOS 26, *)
struct GetLastNightTool: Tool {
    let health: HealthStore
    let name = "getLastNight"
    let description = "Last night's sleep stages, 7-night sleep debt and bedtime consistency."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            guard let n = health.lastSleep else { return "no sleep recorded" }
            let st = SleepStage.allCases.map { "\($0.rawValue) \(Int(n.minutes($0)))m" }.joined(separator: ", ")
            let debt = Int(Insights.sleepDebt(health.recentNights))
            let spread = Insights.bedtimeSpread(health.recentNights).map { "\(Int($0))m" } ?? "n/a"
            return "\(st); sleepDebt7d=\(debt)m; bedtimeSpread=\(spread)"
        }
    }
}

@available(iOS 26, *)
struct GetActivityTodayTool: Tool {
    let health: HealthStore
    let name = "getActivityToday"
    let description = "Steps, active kcal, workouts today, and stressed hours (high HR while still)."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let w = health.todayWorkouts.filter { !$0.isWalk }.map { "\($0.name) \(Int($0.minutes))m" }
            let stressed = health.stressHours.filter { ($0.level ?? 0) >= 0.6 }.count
            return "steps=\(Int(health.stepsToday ?? 0)); kcal=\(Int(health.activeEnergyToday ?? 0)); workouts=\(w.isEmpty ? "none" : w.joined(separator: ", ")); stressedHours=\(stressed)"
        }
    }
}

@available(iOS 26, *)
struct GetHistoryTool: Tool {
    let health: HealthStore
    let name = "getHistory"
    let description = "Daily recovery, sleep minutes, steps and strain for the last N days (max 14)."
    @Generable struct Arguments { @Guide(.range(3...14)) var days: Int }
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            health.history.suffix(arguments.days).map { d in
                "\(d.date.formatted(.dateTime.weekday(.abbreviated))): rec \(d.recovery.map(String.init) ?? "-"), sleep \(d.sleepMinutes.map { String(Int($0)) } ?? "-")m, strain \(d.strain.map { String(format: "%.1f", $0) } ?? "-")"
            }.joined(separator: " | ")
        }
    }
}

// MARK: - Structured turn: reply + tappable suggested replies

@available(iOS 26, *)
@Generable struct CoachTurn {
    @Guide(description: "Plain-language answer, at most 90 words, grounded only in tool data. No diagnosis.")
    var reply: String
    @Guide(description: "Short follow-up questions the user might tap, under 6 words each", .count(3))
    var suggestions: [String]
}

// MARK: - Engine

@available(iOS 26, *)
@Observable @MainActor
final class CoachEngine {
    enum Mode { case onDevice, unavailable(String) }
    var mode: Mode = .unavailable("")
    var replyText = ""          // streams in
    var suggestions: [String] = ["How did I sleep?", "Should I train hard today?", "Why is my recovery low?"]
    var isResponding = false
    private var session: LanguageModelSession?
    private let health: HealthStore

    static let instructions = """
    You are the MRH1 coach: a calm, practical wellness guide. Always call a tool before stating a number. \
    Compare with the user's own normal, not population norms. Give one concrete next step. \
    You are not a doctor: never diagnose, never interpret symptoms; for chest pain, fainting, or feeling unwell, \
    say to contact a doctor or emergency services. HRV, skin temperature and VO2 max are not available.
    """

    init(health: HealthStore) {
        self.health = health
        switch SystemLanguageModel.default.availability {
        case .available: mode = .onDevice; newSession()
        case .unavailable(.deviceNotEligible): mode = .unavailable("This iPhone can't run Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled): mode = .unavailable("Turn on Apple Intelligence in Settings to chat.")
        case .unavailable(.modelNotReady): mode = .unavailable("The on-device model is still downloading.")
        case .unavailable: mode = .unavailable("Coach chat is unavailable right now.")
        }
    }

    private func newSession() {
        let tools: [any Tool] = [GetTodayScoresTool(health: health), GetMetricStateTool(health: health),
                                 GetLastNightTool(health: health), GetActivityTodayTool(health: health),
                                 GetHistoryTool(health: health)]
        session = LanguageModelSession(tools: tools, instructions: Self.instructions)
        session?.prewarm()
    }

    func send(_ text: String) async {
        guard let session, !session.isResponding else { return }
        isResponding = true; replyText = ""; defer { isResponding = false }
        do {
            let stream = session.streamResponse(to: text, generating: CoachTurn.self,
                                                options: GenerationOptions(temperature: 0.4))
            for try await snap in stream {
                if let r = snap.content.reply { replyText = r }
                if let s = snap.content.suggestions, s.count == 3 { suggestions = s }
            }
        } catch {
            handle(error, retrying: text)
        }
    }

    private func handle(_ error: Error, retrying text: String) {
        if #available(iOS 27, *), let e = error as? LanguageModelError {
            switch e {
            case .contextSizeExceeded: newSession(); replyText = "Let's start fresh. Ask me again?"
            case .guardrailViolation, .refusal: replyText = Self.safeDecline
            case .unsupportedLanguageOrLocale: replyText = "I can't chat in this language yet."
            default: replyText = "The coach is busy. Try again in a moment."
            }
        } else if let e = error as? LanguageModelSession.GenerationError {
            switch e {
            case .exceededContextWindowSize: newSession(); replyText = "Let's start fresh. Ask me again?"
            case .guardrailViolation, .refusal: replyText = Self.safeDecline
            default: replyText = "The coach is busy. Try again in a moment."
            }
        }
    }
    static let safeDecline = "I can't help with that one. For anything about symptoms or treatment, please talk to a doctor."
}

// MARK: - View (streams; falls back to rule-based coach)

struct CoachView: View {
    @Environment(HealthStore.self) private var health
    var body: some View {
        if #available(iOS 26, *) { CoachChat(health: health) } else { RuleCoachView() }
    }
}

@available(iOS 26, *)
private struct CoachChat: View {
    @State private var engine: CoachEngine
    init(health: HealthStore) { _engine = State(initialValue: CoachEngine(health: health)) }
    var body: some View {
        switch engine.mode {
        case .unavailable(let why): RuleCoachView(note: why)
        case .onDevice:
            VStack(alignment: .leading, spacing: Space.l) {
                Text(engine.replyText).typo(.body).foregroundStyle(Theme.ink)
                    .animation(.default, value: engine.replyText)
                HStack { ForEach(engine.suggestions, id: \.self) { s in
                    Button(s) { Task { await engine.send(s) } }.buttonStyle(.bordered).disabled(engine.isResponding)
                } }
                Text("Wellness guidance, not medical advice. Runs on this iPhone.").typo(.caption).foregroundStyle(Theme.text3)
            }
        }
    }
}
// RuleCoachView: deterministic coach built from Insights.trend / Scores.strainTarget / sleepDebt,
// with the same preset chips answered by templates (works on iOS 17+, every device).
```

Things to verify in Xcode 27: whether the `streamResponse(to:generating:options:)` snapshot field names match, and whether passing a `@MainActor` store into a `Sendable` tool compiles cleanly under Swift 6 strict concurrency.

## Decisions for MRH1 v1.1

1. **Engine = Apple Foundation Models on-device (`SystemLanguageModel.default`)**, accessed only through tools that read MRH1's own computed data. No cloud LLM in v1.1. The privacy line becomes: "Everything, including the coach, runs on this iPhone. No internet code."
2. **Keep the iOS 17 deployment target.** Gate the coach with `#if canImport(FoundationModels)` + `@available(iOS 26, *)`. Build against the iOS 27 SDK and handle both `LanguageModelError` (27) and `GenerationError` (26.x).
3. **Ship a rule-based coach as the fallback, which also serves as the coach's ground truth**: proactive tips and preset chips answered by templates over `Insights.trend`, `Scores.strainTarget`, `Insights.sleepDebt`, `bedtimeSpread`, `stressHours`. Show it on every non-AI device, when Apple Intelligence is off, while the model downloads, and in unsupported languages. Show one plain line explaining why, with a Settings hint for `.appleIntelligenceNotEnabled`.
4. **Five read-only tools, as drafted**: `getTodayScores`, `getMetricState` (an `.anyOf` over `MetricID` minus `.hrv`/`.skinTemp`), `getLastNight`, `getActivityToday`, `getHistory` (≤14 days). Add `getJournalTags` (over `JournalStore.entries`) when discoveries are wired in. Tool output stays as compact strings of ≤ ~60 tokens each.
5. **Fit the context budget**: instructions ≤ 250 tokens. Each turn is one `@Generable CoachTurn` (reply ≤ 90 words + exactly 3 suggestions). Check `contextSize` and `tokenCount(for:)` at runtime. On context overflow, start a new session seeded with a one-line summary. Don't keep chat history across launches in v1.1.
6. **Proactive recommendations** are generated once per foreground refresh, after `HealthStore.refresh()`, with non-streaming `respond`. Cache them for the day. Never generate from background tasks. Notifications use the rule-based text only.
7. **Safety**: coach instructions forbid diagnosis and route symptoms to "talk to a doctor". Guardrail or refusal errors map to `safeDecline`. Every coach screen carries the "wellness, not medical advice" caption (1.4.1). Add a crisis-safe canned response for self-harm keywords, checked before the model is called (FM acceptable-use rules).
8. **Languages**: v1.1 coach launches in the 16 Apple Intelligence languages. Instructions stay in English, and the system prompt tells the model to "reply in the user's language". Unsupported locales get the rule-based coach.
9. **No Claude, Gemini, or other third-party AI in v1.1.** Revisit "Deeper answers" for v1.2 as an opt-in only, in this order:
   - (a) Apple PCC (`PrivateCloudComputeLanguageModel`, free under the Small Business Program, attested, iOS 27+). The owner must enrol in the paid developer program and request the PCC entitlement first.
   - (b) Only if PCC isn't enough: `claude-haiku-5-5` behind a proxy (~$0.35/user/month), with a 5.1.2(i) consent sheet naming Anthropic, a privacy-label update, and a send-preview of exactly which numbers leave the phone.
10. **QA**: test prompts on iOS 26.4 and iOS 27 models with the Foundation Models Instrument. Keep a 30-question golden set (sleep, strain, "should I train", symptom traps) and re-run it every OS update, because Apple changes the model with each release.
