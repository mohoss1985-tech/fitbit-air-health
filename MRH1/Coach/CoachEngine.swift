import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// v1.1 Coach · conversation engine. Owner: agent L.
//
// On-device Apple Foundation Models only (no network code). Falls back to the rule-based coach
// (`CoachRules.templateReply`) on iOS < 26, without Apple Intelligence, while the model downloads,
// in unsupported languages, or when AI chat is switched off. Every turn:
//   user message → CoachSafety.preCheck → (model with 9 tools → CoachTurn) → CoachReply → CoachSafety.postCheck
//   → 1 retry → template reply.
// Transcripts stay on this iPhone (Application Support/Coach, excluded from backup) for 30 days.

@Observable @MainActor
final class CoachEngine {
    enum Mode: Equatable { case onDevice, rules(reason: String) }

    /// Current conversation, oldest first. The last coach message updates while it streams.
    var messages: [CoachMessage] = []
    var isThinking = false
    /// Real status from the tool being called ("Reading your last 7 nights…"); nil when idle.
    var statusText: String? = nil
    var mode: Mode = .rules(reason: "Coach is starting.")
    /// Earlier conversations (newest first), kept 30 days. The current chat is not included.
    private(set) var history: [CoachChat] = []
    /// Metric the current chat was started about (CoachMark / "Ask about this").
    private(set) var focusMetric: MetricID? = nil

    /// True when replies run on demo data ("Sample data").
    var isSample: Bool { Demo.isOn }
    /// True once `configure(health:journal:)` was called.
    var isConfigured: Bool { context != nil }
    var isOnDevice: Bool { mode == .onDevice }
    /// Data-generated starter questions for the Coach tab (from `CoachRules.starters`).
    var starters: [String] { context.map { CoachRules.starters(health: $0.health) } ?? Self.defaultChips }

    /// UserDefaults key: false = AI chat off, rule-based coach only (default true).
    static let aiEnabledKey = "mrh1.coachAI"
    /// UserDefaults key: "direct" (default) · "supportive" · "numbers".
    static let styleKey = CoachPrefs.Key.style
    /// Transcripts older than this are deleted.
    static let retentionDays = 30
    /// User turns per model session before it restarts seeded with a summary (keeps the 4K window safe).
    static let turnsPerSession = 6

    /// Fixed reply when the model's guardrails refuse a request.
    static let decline = CoachReply(
        headline: "I can’t help with that one here.",
        body: "For symptoms, treatment or medication, please talk to a doctor. I can help with sleep, training and recovery from your own data.",
        chips: ["How did I sleep?", "How hard today?", "What should I train?"],
        isTemplate: true)

    static let defaultChips = ["How did I sleep?", "How hard today?", "What should I train?"]

    @ObservationIgnored private var context: CoachToolContext?
    @ObservationIgnored private var currentChatID = UUID()
    @ObservationIgnored private var currentStarted = Date()
    @ObservationIgnored private var session: AnyObject?   // LanguageModelSession (iOS 26+)
    @ObservationIgnored private var sessionTurns = 0
    @ObservationIgnored private var seedSummary: String?
    @ObservationIgnored private let persists: Bool
    /// Set after a crisis / emergency / minor reply: the model stays off until `newChat()`.
    @ObservationIgnored private var pausedCategory: CoachSafety.Category?

    init() {
        persists = !Demo.isOn
        refreshMode()
        loadTranscripts()
    }

    // MARK: - Setup

    /// Hands the engine the app's stores (O calls this once, e.g. in MRH1App / ContentView `.task`).
    func configure(health: HealthStore, journal: JournalStore) {
        if let c = context, c.health === health, c.journal === journal { refreshMode(); return }
        let ctx = CoachToolContext(health: health, journal: journal)
        ctx.onStatus = { [weak self] s in self?.statusText = s }
        context = ctx
        session = nil
        refreshMode()
        prewarm()
    }

    /// Re-reads model availability and the AI setting (call on foreground / after Settings changes).
    func refreshMode() {
        let old = mode
        mode = Self.detectMode()
        if mode != old { session = nil }
    }

    static func detectMode() -> Mode {
        if UserDefaults.standard.object(forKey: aiEnabledKey) != nil, !UserDefaults.standard.bool(forKey: aiEnabledKey) {
            return .rules(reason: "AI chat is off. Coach answers with simple rules. Turn it on in Menu › Coach.")
        }
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                if !model.supportsLocale() {
                    return .rules(reason: "Coach chat isn’t available in your language yet, so it uses simple rules.")
                }
                return .onDevice
            case .unavailable(.deviceNotEligible):
                return .rules(reason: "This iPhone can’t run Apple Intelligence, so Coach uses simple rules.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .rules(reason: "Turn on Apple Intelligence in Settings for full chat. Simple rules for now.")
            case .unavailable(.modelNotReady):
                return .rules(reason: "The on-device model is still downloading. Simple rules for now.")
            case .unavailable:
                return .rules(reason: "Coach chat isn’t available right now, so it uses simple rules.")
            }
        }
        #endif
        return .rules(reason: "Full chat needs iOS 26 and Apple Intelligence. Coach uses simple rules.")
    }

    /// Warms the on-device model so the first reply starts faster.
    func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), mode == .onDevice, context != nil {
            currentSession().prewarm()
        }
        #endif
    }

    // MARK: - Chats

    /// Starts a chat about a metric (CoachMark / "Ask about this"): a new chat with an instant opener
    /// built from real data (no model), and 3 metric chips. nil = plain new chat.
    func start(about metric: MetricID?) {
        if !messages.isEmpty { newChat() }
        focusMetric = metric
        guard let metric, let ctx = context else { return }
        messages.append(.coach(opener(for: metric, ctx: ctx)))
        save()
    }

    /// Archives the current chat and starts an empty one (model session restarts).
    func newChat() {
        archiveCurrent()
        messages = []
        focusMetric = nil
        currentChatID = UUID()
        currentStarted = Date()
        session = nil
        sessionTurns = 0
        seedSummary = nil
        pausedCategory = nil
        isThinking = false
        statusText = nil
        save()
    }

    /// Re-opens a past chat from `history`; the model session restarts seeded with a summary.
    func open(_ chat: CoachChat) {
        guard chat.id != currentChatID else { return }
        archiveCurrent()
        history.removeAll { $0.id == chat.id }
        messages = chat.messages
        currentChatID = chat.id
        currentStarted = chat.started
        focusMetric = chat.messages.compactMap(\.metric).last
        session = nil
        sessionTurns = 0
        seedSummary = Self.summary(of: chat.messages)
        pausedCategory = nil
        save()
    }

    /// Wipes every transcript on this iPhone (Menu › Delete coach history).
    func deleteAll() {
        messages = []
        history = []
        focusMetric = nil
        currentChatID = UUID()
        currentStarted = Date()
        session = nil
        sessionTurns = 0
        seedSummary = nil
        pausedCategory = nil
        isThinking = false
        statusText = nil
        if let url = Self.fileURL() { try? FileManager.default.removeItem(at: url) }
    }

    private func archiveCurrent() {
        guard messages.contains(where: { $0.role == .user }) else { return }
        history.removeAll { $0.id == currentChatID }
        history.insert(CoachChat(id: currentChatID, started: currentStarted, messages: messages), at: 0)
    }

    // MARK: - Send

    func send(_ text: String, about metric: MetricID? = nil) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }
        let about = metric ?? focusMetric
        if let metric { focusMetric = metric }
        messages.append(.user(question, about: metric))
        save()

        // 1 · Safety first: emergencies / crisis / medical get fixed copy, never the model.
        let category = CoachSafety.category(of: question)
        if var fixed = CoachSafety.preCheck(question) {
            fixed.isTemplate = true
            fixed.isSample = isSample
            if let c = category, c.endsCoaching { pausedCategory = c }
            messages.append(.coach(fixed))
            save()
            return
        }
        // After a crisis / emergency / minor reply, no coaching until a new chat: repeat the fixed copy.
        if let c = pausedCategory, var fixed = CoachSafety.reply(for: c) {
            fixed.isTemplate = true
            fixed.isSample = isSample
            messages.append(.coach(fixed))
            save()
            return
        }

        guard let ctx = context else {
            messages.append(.coach(CoachReply(
                headline: "Coach is still loading your data.",
                body: "Try again in a moment.",
                chips: Self.defaultChips, isTemplate: true, isSample: isSample)))
            save()
            return
        }
        ctx.beginTurn()
        ctx.allow(question)

        isThinking = true
        statusText = "Reading your data…"
        defer { isThinking = false; statusText = nil }

        // 2 · Rules mode: template reply only.
        guard mode == .onDevice else {
            messages.append(.coach(template(question, metric: about, ctx: ctx)))
            save()
            return
        }

        // 3 · On-device model.
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let id = UUID()
            messages.append(CoachMessage(id: id, role: .coach,
                                         reply: CoachReply(headline: "", body: "", isSample: isSample, isStreaming: true)))
            let reply = await modelReply(question, metric: about, ctx: ctx, messageID: id,
                                         guidance: CoachSafety.modelGuidance(for: category))
            update(id) { $0 = reply }
            save()
            return
        }
        #endif
        messages.append(.coach(template(question, metric: about, ctx: ctx)))
        save()
    }

    /// Rule-based reply (fallback and rules mode).
    private func template(_ question: String, metric: MetricID?, ctx: CoachToolContext) -> CoachReply {
        var r = CoachRules.templateReply(for: question, metric: metric, health: ctx.health, journal: ctx.journal)
        r.isTemplate = true
        r.isSample = isSample
        r.isStreaming = false
        r.chips = Self.cleanChips(r.chips, maxWords: 6)   // reviewed copy from CoachRules: only fix the count
        return r
    }

    private func update(_ id: UUID, _ change: (inout CoachReply) -> Void) {
        guard let i = messages.firstIndex(where: { $0.id == id }) else { return }
        var r = messages[i].reply ?? CoachReply(headline: "", body: "")
        change(&r)
        messages[i].reply = r
    }

    // MARK: - Opener (instant, from data)

    private func opener(for metric: MetricID, ctx: CoachToolContext) -> CoachReply {
        let name = metric.info.name
        let s = ctx.health.state(metric)
        var headline: String
        var body: String
        var pills: [DataPill] = []
        if metric.isNotSentByGoogle {
            headline = "\(name) is not sent by Google Health."
            body = "Coach uses resting heart rate, breathing rate and sleep instead. Ask me about any of them."
        } else if !s.hasData {
            headline = "No \(name.lowercased()) reading yet."
            body = (s.missing?.text ?? MissingState.noReading.text) + ". Ask me anything about your other data."
        } else {
            let unit = metric.info.unit.isEmpty ? "" : " " + metric.info.unit
            headline = "\(name): \(s.valueText)\(unit), \(s.flag.directionWord.lowercased())."
            body = metric.info.what
            if let p = ctx.pill(for: metric) { pills = [p] }
        }
        if let e = s.earlyReadText { body += " " + e }
        return CoachReply(headline: headline, body: body, pills: pills, chips: Self.chips(for: metric, state: s),
                          isTemplate: true, isSample: isSample)
    }

    /// Three standalone questions (≤ 4 words) about a metric.
    static func chips(for metric: MetricID, state s: MetricState) -> [String] {
        let short = CoachToolContext.shortName(metric)
        var first = "What does this mean?"
        if s.isConcern {
            first = s.flag == .high ? "Why is \(short) up?" : "Why is \(short) down?"
        }
        switch metric.info.panel {
        case .sleep: return [first, "Help me sleep better?", "How was last night?"]
        case .activity: return [first, "What should I train?", "How hard today?"]
        default: return [first, "Is this my normal?", "Should I train today?"]
        }
    }

    // MARK: - Chip and length rules (DESIGN_SPEC_v1.1 §5)

    /// Exactly 3 unique chips, each ≤ 4 words; bad ones replaced by defaults.
    static func cleanChips(_ raw: [String], maxWords: Int = 4) -> [String] {
        var out: [String] = []
        for c in raw {
            let t = c.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"“”")))
            let words = t.split(separator: " ").count
            guard words >= 2, words <= maxWords,
                  !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else { continue }
            out.append(t)
            if out.count == 3 { break }
        }
        for d in defaultChips where out.count < 3 && !out.contains(d) { out.append(d) }
        return out
    }

    static func clipWords(_ s: String, _ n: Int) -> String {
        let words = s.split(separator: " ")
        guard words.count > n else { return s }
        return words.prefix(n).joined(separator: " ")
    }

    /// ≤ 3 sentences and ≤ `words` words.
    static func clipBody(_ s: String, sentences: Int = 3, words: Int = 60) -> String {
        var out = ""
        var count = 0
        s.enumerateSubstrings(in: s.startIndex..., options: .bySentences) { sub, _, _, stop in
            guard let sub else { return }
            out += sub
            count += 1
            if count >= sentences { stop = true }
        }
        let trimmed = (out.isEmpty ? s : out).trimmingCharacters(in: .whitespacesAndNewlines)
        let w = trimmed.split(separator: " ")
        return w.count > words ? w.prefix(words).joined(separator: " ") + "…" : trimmed
    }

    // MARK: - Summary (session seed)

    static func summary(of msgs: [CoachMessage]) -> String? {
        let lastQ = msgs.last(where: { $0.role == .user })?.text
        let lastA = msgs.last(where: { $0.role == .coach })?.reply?.headline
        guard lastQ != nil || lastA != nil else { return nil }
        var s = "Earlier in this chat:"
        if let q = lastQ { s += " the user asked “\(clipWords(q, 16))”" }
        if let a = lastA, !a.isEmpty { s += "; you answered “\(clipWords(a, 14))”" }
        return s + "."
    }

    // MARK: - Persistence (on device only, excluded from backup, 30 days)

    private struct FileData: Codable {
        var current: CoachChat?
        var history: [CoachChat]
    }

    private static func directory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        var dir = base.appendingPathComponent("Coach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }

    private static func fileURL() -> URL? { directory()?.appendingPathComponent("transcripts.json") }

    private func save() {
        guard persists, let url = Self.fileURL() else { return }
        var current: CoachChat? = nil
        let saved = messages.map { m -> CoachMessage in
            var m = m
            m.reply?.isStreaming = false
            return m
        }
        if !saved.isEmpty { current = CoachChat(id: currentChatID, started: currentStarted, messages: saved) }
        let data = FileData(current: current, history: history)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let bytes = try? enc.encode(data) else { return }
        do {
            try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var u = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? u.setResourceValues(values)
        } catch {}
    }

    private func loadTranscripts() {
        guard persists, let url = Self.fileURL(), let bytes = try? Data(contentsOf: url) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let data = try? dec.decode(FileData.self, from: bytes) else { return }
        let cutoff = Date().addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        history = data.history.filter { $0.lastActivity >= cutoff }.sorted { $0.lastActivity > $1.lastActivity }
        if let cur = data.current, cur.lastActivity >= cutoff {
            // Resume today's chat; older ones go to History.
            if Date().timeIntervalSince(cur.lastActivity) < 12 * 3600 {
                messages = cur.messages
                currentChatID = cur.id
                currentStarted = cur.started
                focusMetric = cur.messages.compactMap(\.metric).last
                seedSummary = Self.summary(of: cur.messages)
            } else if cur.messages.contains(where: { $0.role == .user }) {
                history.insert(cur, at: 0)
            }
        }
        if history.count != data.history.count || data.current == nil { save() }
    }

    /// Deletes transcripts older than 30 days (also runs at every launch).
    func purgeOld() {
        let cutoff = Date().addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        history.removeAll { $0.lastActivity < cutoff }
        save()
    }

    // MARK: - Instructions (≤ 250 tokens)

    private func instructions(ctx: CoachToolContext) -> String {
        let cap = ctx.rules.cap.rawValue
        var s = """
        You are MRH1 Coach, a calm wellness coach on this iPhone. You explain the user's own Fitbit Air data \
        from Apple Health. Wellness guidance only, never medical advice.
        - Call tools before answering. Use only numbers tools return; never estimate or calculate.
        - Compare with the user's own normal.
        - headline: at most 14 words. body: at most 3 short sentences, under 60 words. Second person. \
        No exclamation marks, no emoji.
        - Today's intensity cap is \(cap). Never suggest anything harder. Exercises only from findSessions; put its id in planID.
        - HRV, skin temperature and VO2 max: say "Not sent by Google Health" and what you use instead.
        - Never diagnose or name diseases, medication, supplements, doses, diets or calorie targets. \
        Say "outside your usual range", never "abnormal" or "danger". Causes are only "possible".
        - chips: exactly 3 questions the user could ask next, at most 4 words each.
        - Reply in the user's language.
        """
        switch UserDefaults.standard.string(forKey: Self.styleKey) {
        case "supportive": s += "\n- Style: warm and encouraging."
        case "numbers": s += "\n- Style: lead with the numbers, very brief."
        default: s += "\n- Style: direct and practical."
        }
        if isSample { s += "\n- This is sample data." }
        if let seed = seedSummary { s += "\n" + seed }
        return s
    }

    // MARK: - Model

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func currentSession() -> LanguageModelSession {
        if let s = session as? LanguageModelSession { return s }
        guard let ctx = context else { return LanguageModelSession() }
        let s = LanguageModelSession(tools: CoachToolbox.all(ctx), instructions: instructions(ctx: ctx))
        session = s
        sessionTurns = 0
        return s
    }

    /// Restarts the model session seeded with a one-line summary of this chat.
    private func rollSession() {
        seedSummary = Self.summary(of: messages.filter { $0.reply?.isStreaming != true })
        session = nil
        sessionTurns = 0
    }

    @available(iOS 26, *)
    private func modelReply(_ question: String, metric: MetricID?, ctx: CoachToolContext, messageID: UUID,
                            guidance: String? = nil) async -> CoachReply {
        if sessionTurns >= Self.turnsPerSession { rollSession() }
        var prompt = Self.prompt(question, metric: metric)
        if let g = guidance { prompt = g + "\n" + prompt }
        var overflowRetried = false

        for attempt in 0..<2 {
            do {
                let turn = try await stream(prompt: attempt == 0 ? prompt : Self.retryPrompt, messageID: messageID)
                sessionTurns += 1
                let reply = map(turn, metric: metric, ctx: ctx)
                if CoachSafety.postCheck(reply, allowedNumbers: ctx.numbers) { return reply }
                // postCheck failed: retry once in the same session, then template.
                update(messageID) { $0.headline = ""; $0.body = "" }
                statusText = "Checking the numbers…"
            } catch {
                switch Self.classify(error) {
                case .overflow where !overflowRetried:
                    overflowRetried = true
                    rollSession()
                    statusText = "Starting a fresh page…"
                    if let turn = try? await stream(prompt: prompt, messageID: messageID) {
                        sessionTurns += 1
                        let reply = map(turn, metric: metric, ctx: ctx)
                        if CoachSafety.postCheck(reply, allowedNumbers: ctx.numbers) { return reply }
                    }
                    return template(question, metric: metric, ctx: ctx)
                case .declined:
                    rollSession()
                    var d = Self.decline
                    d.isSample = isSample
                    return d
                case .language:
                    mode = .rules(reason: "Coach chat isn’t available in your language yet, so it uses simple rules.")
                    session = nil
                    return template(question, metric: metric, ctx: ctx)
                default:
                    rollSession()
                    return template(question, metric: metric, ctx: ctx)
                }
            }
        }
        return template(question, metric: metric, ctx: ctx)
    }

    static let retryPrompt = "Your last answer broke a rule: a number no tool returned, or a medical word. Answer the same question again using only numbers from tool results and plain wellness words."

    static func prompt(_ question: String, metric: MetricID?) -> String {
        let when = Demo.now.formatted(.dateTime.weekday(.wide))
        let h = Calendar.current.component(.hour, from: Demo.now)
        let part = h < 12 ? "morning" : (h < 18 ? "afternoon" : "evening")
        var p = "(\(when) \(part)"
        if let m = metric { p += ", about \(m.info.name), metric id \(m.rawValue)" }
        return p + ") " + question
    }

    @available(iOS 26, *)
    private func stream(prompt: String, messageID: UUID) async throws -> CoachTurn.PartiallyGenerated? {
        let s = currentSession()
        let options = GenerationOptions(temperature: 0.3, maximumResponseTokens: 320)
        let stream = s.streamResponse(to: prompt, generating: CoachTurn.self, options: options)
        var last: CoachTurn.PartiallyGenerated?
        for try await snap in stream {
            let c = snap.content
            last = c
            if c.headline != nil || c.body != nil { statusText = nil }
            update(messageID) { r in
                r.headline = Self.clipWords(c.headline ?? "", 14)
                r.body = c.body ?? ""
                r.isStreaming = true
            }
        }
        return last
    }

    @available(iOS 26, *)
    private func map(_ turn: CoachTurn.PartiallyGenerated?, metric: MetricID? = nil, ctx: CoachToolContext) -> CoachReply {
        var pills: [DataPill] = []
        for raw in turn?.pills ?? [] {
            guard let id = MetricID(rawValue: raw), !pills.contains(where: { $0.metric == id }),
                  let p = ctx.pill(for: id) else { continue }
            pills.append(p)
            if pills.count == 3 { break }
        }
        // A chat about a metric always shows that metric's pill (1–3 pills per reply, DESIGN_SPEC_v1.1 §5).
        if pills.isEmpty, let m = metric, let p = ctx.pill(for: m) { pills = [p] }
        let headline = Self.clipWords((turn?.headline ?? "").trimmingCharacters(in: .whitespacesAndNewlines), 14)
        let body = Self.clipBody(turn?.body ?? "")
        return CoachReply(headline: headline.isEmpty ? "Here is what your data shows." : headline,
                          body: body,
                          pills: pills,
                          chips: Self.cleanChips(turn?.chips ?? []),
                          plan: ctx.plan(id: turn?.planID),
                          isTemplate: false,
                          isSample: isSample,
                          isStreaming: false)
    }

    enum ErrorKind { case overflow, declined, language, other }

    static func classify(_ error: Error) -> ErrorKind {
        if #available(iOS 27, *), let e = error as? LanguageModelError {
            switch e {
            case .contextSizeExceeded: return .overflow
            case .guardrailViolation, .refusal: return .declined
            case .unsupportedLanguageOrLocale: return .language
            default: return .other
            }
        }
        if #available(iOS 26, *), let e = error as? LanguageModelSession.GenerationError {
            switch e {
            case .exceededContextWindowSize: return .overflow
            case .guardrailViolation, .refusal: return .declined
            case .unsupportedLanguageOrLocale: return .language
            default: return .other
            }
        }
        return .other
    }
    #endif
}

// MARK: - Structured turn (guided generation)

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct CoachTurn {
    @Guide(description: "Answer in at most 14 words: the change vs their normal and one action.")
    var headline: String
    @Guide(description: "At most 3 short sentences, under 60 words. Numbers only from tools.")
    var body: String
    @Guide(description: "Metric ids you cited, at most 3", .maximumCount(3),
           .element(.anyOf(["restingHR", "sleepingHR", "breathing", "spo2", "sleepTotal", "deepSleep",
                            "remSleep", "awake", "steps", "energy", "workoutMinutes"])))
    var pills: [String]
    @Guide(description: "Exactly 3 follow-up questions, at most 4 words each", .count(3))
    var chips: [String]
    @Guide(description: "Session id from findSessions, or empty")
    var planID: String
}
#endif
