import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// v1.1 Coach · 9 read-only tools over HealthStore / JournalStore (getToday, getMetric, getSleep, getLoad,
// getSignals, getJournal, getWeekly, getProfile, findSessions). Owner: agent L.
//
// The model never touches HealthKit: every tool reads the already-computed @MainActor stores through
// `CoachToolContext`, returns a compact pre-formatted string (numbers copied, never computed by the model),
// and records every number it returned so `CoachSafety.postCheck` can reject invented ones.

/// MainActor snapshot of what the coach may read, plus the per-turn number log.
@MainActor
final class CoachToolContext {
    let health: HealthStore
    let journal: JournalStore
    var profile: CoachProfile
    var rules: CoachRuleResult
    /// Called with a plain status line whenever a tool runs ("Reading your last 7 nights…").
    var onStatus: ((String) -> Void)?

    /// Every number any tool (or pill) returned this turn, in several spellings ("7.5", "7,5", "7").
    private(set) var numbers: Set<String> = []
    /// Library sessions returned by `findSessions` this chat (id → plan); a reply may only attach these.
    private(set) var plans: [String: CoachPlan] = [:]
    /// Tool names called this turn (debug / tests).
    private(set) var calls: [String] = []
    /// v1.3 B5: metric this turn is about (from `CoachRules.focus`), nil = general / recovery / plan.
    private(set) var focusMetric: MetricID?
    /// v1.3 B5: journal tags tools may quote this turn (nil = all). Set by the engine each turn.
    private(set) var allowedTags: Set<String>?

    /// Sets what this turn is about (call after `beginTurn()`).
    func setFocus(metric: MetricID?, allowedTags: Set<String>?) {
        focusMetric = metric
        self.allowedTags = allowedTags
    }

    init(health: HealthStore, journal: JournalStore, profile: CoachProfile = .saved) {
        self.health = health
        self.journal = journal
        self.profile = profile
        self.rules = CoachRules.evaluate(health, journal: journal)
    }

    /// Re-reads rules and profile and clears the per-turn log. Call before each user turn.
    func beginTurn() {
        rules = CoachRules.evaluate(health, journal: journal)
        profile = .saved
        numbers = []
        calls = []
        focusMetric = nil
        allowedTags = nil
    }

    /// Adds every number in `text` to the allowed set (e.g. numbers the user typed).
    func allow(_ text: String) { numbers.formUnion(Self.numbers(in: text)) }

    private func emit(_ tool: String, status: String, _ out: String) -> String {
        calls.append(tool)
        onStatus?(status)
        allow(out)
        return out
    }

    // MARK: Number extraction

    /// All numbers in a string, normalised: "7,5" → {"7,5","7.5","7"}, "4 210" / "4,210" → {"4210", …}.
    nonisolated static func numbers(in text: String) -> Set<String> {
        var out: Set<String> = []
        // Collapse thousands separators ("4,210", "4 210", "4.210" with 3 digits after) into one token too.
        let pattern = #"\d+(?:[.,\x{00A0}\x{202F}]\d+)*"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let raw = ns.substring(with: m.range)
            out.insert(raw)
            let parts = raw.components(separatedBy: CharacterSet(charactersIn: ".,\u{00A0}\u{202F} "))
            for p in parts where !p.isEmpty { out.insert(p) }
            if parts.count == 2 {
                out.insert(parts[0] + "." + parts[1])
                out.insert(parts[0] + "," + parts[1])
            }
            if parts.count >= 2, parts.dropFirst().allSatisfy({ $0.count == 3 }) {
                out.insert(parts.joined())
            }
            // Rounded forms of decimals ("7.6" may be said as "8").
            if parts.count == 2, let v = Double(parts[0] + "." + parts[1]) {
                out.insert(String(Int(v.rounded())))
            }
        }
        return out
    }

    // MARK: Helpers

    private func fmt1(_ v: Double) -> String { String(format: "%.1f", locale: .current, v) }

    private func zWord(_ z: Double) -> String {
        z <= -1 ? "worse than usual" : (z >= 1 ? "better than usual" : "about usual")
    }

    private func dayWord(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(d, inSameDayAs: Demo.now) { return "today" }
        if let y = cal.date(byAdding: .day, value: -1, to: Demo.now), cal.isDate(d, inSameDayAs: y) { return "yesterday" }
        return d.formatted(.dateTime.weekday(.abbreviated))
    }

    static let notSentIDs: Set<String> = ["hrv", "skinTemp", "vo2Max"]

    static func notSentText(_ name: String) -> String {
        "\(name): \(MissingState.notSent.text). Coach uses resting heart rate, breathing rate and sleep instead."
    }

    var maxHR: Double {
        if let a = health.age { return 208 - 0.7 * Double(a) }
        return 185
    }

    /// Short names for pills ("RHR 58 · normal 54–57").
    static func shortName(_ id: MetricID) -> String {
        switch id {
        case .restingHR: return "RHR"
        case .hrv: return "HRV"
        case .sleepingHR: return "Sleep HR"
        case .breathing: return "Breathing"
        case .spo2: return "SpO2"
        case .skinTemp: return "Skin temp"
        case .sleepTotal: return "Sleep"
        case .deepSleep: return "Deep"
        case .remSleep: return "REM"
        case .awake: return "Awake"
        case .steps: return "Steps"
        case .energy: return "Active"
        case .workoutMinutes: return "Workouts 7d"
        }
    }

    /// DataPill built from real data (never from model text). nil when there is no value.
    func pill(for id: MetricID) -> DataPill? {
        if id.isNotSentByGoogle { return DataPill(metric: id, text: "\(Self.shortName(id)) · Not sent", tier: nil) }
        let s = health.state(id)
        guard s.hasData else { return nil }
        let unit = id.info.unit.isEmpty || id == .steps ? "" : " " + id.info.unit
        var text = "\(Self.shortName(id)) \(s.valueText)\(unit)"
        if let b = s.baseline {
            text += " · normal " + id.format(b.low) + "–" + id.format(b.high)
        }
        allow(text)
        return DataPill(metric: id, text: text, tier: s.statusTier)
    }

    // MARK: - The 9 tools (plain functions; the FoundationModels wrappers below call these)

    func getToday() -> String {
        var p: [String] = []
        if let r = health.recovery {
            let band = r.score >= 67 ? "green" : (r.score >= 34 ? "yellow" : "red")
            var s = "recovery \(r.score)% (\(band)"
            if let sig = r.signalsText { s += ", \(sig)" }
            s += ")"
            let drivers = r.contributors.filter { !$0.id.isNotSentByGoogle }
                .map { "\($0.label) \($0.valueText) \(zWord($0.z))" }
            if !drivers.isEmpty { s += "; drivers: " + drivers.joined(separator: ", ") }
            p.append(s)
        } else {
            let early = health.state(.restingHR).earlyReadText ?? "Calibrating: a few more nights with the Air."
            p.append("recovery: none yet (\(early))")
        }
        p.append("sleepScore " + (health.sleepScore.map(String.init) ?? "none"))
        let t = Scores.todayStrainTarget(health)
        if let st = health.strain {
            p.append("strain \(fmt1(st.value)) of 21, target \(Int(t.lowerBound))–\(Int(t.upperBound))"
                     + (st.value >= t.upperBound ? " (target reached)" : ""))
        } else {
            p.append("strain: no heart rate yet today, target \(Int(t.lowerBound))–\(Int(t.upperBound))")
        }
        if let last = health.stressHours.last(where: { $0.level != nil }), let lv = last.level {
            let high = health.stressHours.filter { ($0.level ?? 0) >= 2 }.count
            p.append("stress now \(Insights.stressWord(lv)), high-stress hours today \(high)")
        }
        p.append("steps today " + (health.stepsToday.map { MetricID.steps.format($0) } ?? "no reading"))
        p.append("active kcal today " + (health.activeEnergyToday.map { MetricID.energy.format($0) } ?? "no reading"))
        let w = health.todayWorkouts.filter { !$0.isWalk }.map { "\($0.name) \(Int($0.minutes.rounded())) min" }
        p.append("workouts today: " + (w.isEmpty ? "none" : w.joined(separator: ", ")))
        if let age = health.syncAge {
            p.append(age < 3600 ? "synced \(Int(age / 60)) min ago" : "synced \(Int(age / 3600)) h ago")
        } else {
            p.append("not synced yet")
        }
        if health.isDemo { p.append("sample data") }
        return emit("getToday", status: "Reading today’s scores…", p.joined(separator: "; "))
    }

    func getMetric(_ raw: String, days: Int) -> String {
        let name: String
        if raw == "vo2Max" { name = "VO2 max" } else { name = MetricID(rawValue: raw)?.info.name ?? raw }
        if Self.notSentIDs.contains(raw) {
            return emit("getMetric", status: "Checking \(name.lowercased())…", Self.notSentText(name))
        }
        guard let id = MetricID(rawValue: raw) else {
            return emit("getMetric", status: "Reading your data…", "unknown metric \(raw)")
        }
        let s = health.state(id)
        let status = "Reading your \(id.info.name.lowercased())…"
        if !s.hasData { return emit("getMetric", status: status, "\(id.info.name): \(s.missing?.text ?? "No reading")") }
        let unit = id.info.unit.isEmpty ? "" : " " + id.info.unit
        var out = "\(id.info.name): latest \(s.valueText)\(unit) (\(dayWord(s.latest!.date))); your normal \(s.yourRangeText); \(s.directionText)"
        if let tier = s.statusTier { out += "; status \(tier.word)" }
        if let m = s.missing { out += "; \(m.text)" }
        if let e = s.earlyReadText { out += "; \(e)" }
        if let tr = Insights.trend(s) { out += "; \(tr.sentence)" }
        if s.isConcern {
            out += "; possible causes if high: \(id.info.ifHigh)"
            // v1.3 B5: which journal tags can affect this metric (the model must not link any other tag).
            let tags = CoachRules.relevantTags(for: id)
            out += tags.isEmpty ? "; no journal tag affects this"
                                : "; journal tags that can affect this: " + tags.sorted().joined(separator: ", ")
        }
        let n = max(3, min(days, 14))
        let series = s.series.suffix(n).map { "\(dayWord($0.date)) \(id.format($0.value))" }
        if !series.isEmpty { out += "; last \(series.count): " + series.joined(separator: ", ") }
        return emit("getMetric", status: status, out)
    }

    func getSleep(nights: Int) -> String {
        let n = max(1, min(nights, 14))
        let status = n == 1 ? "Reading last night…" : "Reading your last \(n) nights…"
        guard let s = health.lastSleep else {
            return emit("getSleep", status: status, "last night: \(MissingState.waiting.text)")
        }
        var out = "last night: asleep \(MetricID.sleepTotal.format(s.asleepMinutes)), in bed \(MetricID.sleepTotal.format(s.inBedMinutes)), efficiency \(Int((s.efficiency * 100).rounded()))%"
        if s.hasStages {
            out += ", deep \(Int(s.minutes(.deep).rounded())) min, REM \(Int(s.minutes(.rem).rounded())) min, light \(Int(s.minutes(.light).rounded())) min"
        } else {
            out += ", no stages"
        }
        out += ", awake \(Int(s.minutes(.awake).rounded())) min"
        out += ", bedtime \(s.start.formatted(date: .omitted, time: .shortened)), woke \(s.end.formatted(date: .omitted, time: .shortened))"
        if let sc = health.sleepScore { out += "; sleep score \(sc)" }
        let debt = Insights.sleepDebt(health.recentNights)
        out += "; sleep debt 7 nights \(MetricID.sleepTotal.format(debt)) (need 8 h)"
        if let spread = Insights.bedtimeSpread(health.recentNights) {
            out += "; bedtime spread ±\(Int(spread.rounded())) min, consistency \(Insights.consistencyScore(spread))"
        }
        if n > 1 {
            let list = health.recentNights.suffix(n).map {
                "\(dayWord($0.end)) \(MetricID.sleepTotal.format($0.asleepMinutes))"
            }
            out += "; nights: " + list.joined(separator: ", ")
        }
        return emit("getSleep", status: status, out)
    }

    func getLoad(days: Int) -> String {
        let n = max(3, min(days, 14))
        let status = "Reading your last \(n) days of training…"
        let rows = health.history.suffix(n).map { d -> String in
            let rec = d.recovery.map { "rec \($0)" } ?? "rec -"
            let st = d.strain.map { "strain \(fmt1($0))" } ?? "strain -"
            let sl = d.sleepMinutes.map { "sleep \(MetricID.sleepTotal.format($0))" } ?? "sleep -"
            return "\(dayWord(d.date)) \(rec), \(st), \(sl)"
        }
        var out = rows.isEmpty ? "no history yet" : rows.joined(separator: " | ")
        let w = health.state(.workoutMinutes)
        if let latest = w.latest?.value {
            out += "; workout minutes last 7 days \(Int(latest.rounded())) (guideline 150 a week)"
            let v = w.series.map(\.value)
            let prior = [7, 14, 21, 28].compactMap { off -> Double? in
                let i = v.count - 1 - off
                return i >= 0 ? v[i] : nil
            }
            if prior.count >= 2 {
                let mean = prior.reduce(0, +) / Double(prior.count)
                if mean > 0 {
                    let ratio = latest / mean
                    let word = ratio > 1.5 ? "big jump vs your usual week, ease in" : (ratio < 0.8 ? "lighter than your usual week" : "close to your usual week")
                    out += "; \(word)"
                }
            }
        } else {
            out += "; workout minutes: no workouts recorded"
        }
        if let st = health.strain {
            let z = st.zoneMinutes.enumerated().map { "Z\($0.offset + 1) \(Int($0.element.rounded()))" }
            out += "; today's zone minutes " + z.joined(separator: ", ")
        }
        let hardDays = health.history.suffix(3).dropLast().filter { ($0.strain ?? 0) >= 14 }.count
        if hardDays >= 2 { out += "; two hard days in a row, today should be easy" }
        return emit("getLoad", status: status, out)
    }

    func getSignals() -> String {
        var out = "intensity cap: \(rules.cap.rawValue) (never suggest anything harder)"
        out += rules.fired.isEmpty ? "; no rules fired" : "; fired: " + rules.fired.joined(separator: "; ")
        if let n = rules.note { out += "; note: \(n.headline) \(n.body)" }
        let concerns = MetricID.allCases.filter { !$0.isNotSentByGoogle && health.state($0).isConcern }
        if !concerns.isEmpty {
            out += "; outside your usual range: " + concerns.map(\.info.name).joined(separator: ", ")
        }
        return emit("getSignals", status: "Checking your signals…", out)
    }

    func getJournal(days: Int) -> String {
        let n = max(1, min(days, 7))
        let cal = Calendar.current
        let today = cal.startOfDay(for: Demo.now)
        var rows: [String] = []
        var hidden = false
        for ago in (0..<n).reversed() {
            guard let d = cal.date(byAdding: .day, value: -ago, to: today) else { continue }
            var tags = journal.entries(for: d)
            // v1.3 B5: only tags that can affect what this turn is about.
            if let allowed = allowedTags {
                let kept = tags.intersection(allowed)
                if kept.count != tags.count { hidden = true }
                tags = kept
            }
            if !tags.isEmpty { rows.append("\(dayWord(d)): " + tags.sorted().joined(separator: ", ")) }
        }
        var out = rows.isEmpty ? (allowedTags == nil ? "no tags" : "no relevant tags") + " in the last \(n) days" : "tags: " + rows.joined(separator: " | ")
        if hidden {
            let about = focusMetric.map { $0.info.name.lowercased() } ?? "this question"
            out += " (only tags that can affect \(about) are listed; do not link other tags to it)"
        }
        var disc = journal.discoveries
        if let allowed = allowedTags {
            let blocked = CoachRules.allTags.filter { !allowed.contains($0) }.map { $0.lowercased() }
            disc = disc.filter { line in !blocked.contains { line.lowercased().contains($0) } }
        }
        if !disc.isEmpty { out += "; discoveries: " + disc.joined(separator: " ") }
        else if let p = journal.progressText { out += "; \(p)" }
        return emit("getJournal", status: "Reading your journal…", out)
    }

    func getWeekly() -> String {
        guard let r = health.weekly else {
            return emit("getWeekly", status: "Reading your week…", "weekly report: not enough data yet")
        }
        var p: [String] = []
        p.append("avg recovery " + (r.avgRecovery.map { "\($0)%" } ?? "none"))
        p.append("avg sleep " + (r.avgSleep.map { MetricID.sleepTotal.format($0) } ?? "none"))
        p.append("sleep debt \(MetricID.sleepTotal.format(r.sleepDebt))")
        p.append("avg steps " + (r.avgSteps.map { MetricID.steps.format($0) } ?? "none"))
        p.append("workout minutes \(Int(r.workoutMinutes.rounded())) (guideline 150)")
        if let b = r.best { p.append("best: \(b.sentence)") }
        if let w = r.worst { p.append("watch: \(w.sentence)") }
        return emit("getWeekly", status: "Reading your week…", "this week: " + p.joined(separator: "; "))
    }

    func getProfile() -> String {
        var p: [String] = []
        p.append("age " + (health.age.map(String.init) ?? "unknown"))
        let m = maxHR
        p.append("max HR \(Int(m.rounded())) bpm")
        let zones = (0..<5).map { i -> String in
            let lo = Int((m * (0.5 + 0.1 * Double(i))).rounded())
            let hi = Int((m * (0.6 + 0.1 * Double(i))).rounded())
            return "Z\(i + 1) \(lo)–\(hi)"
        }
        p.append("zones bpm " + zones.joined(separator: ", "))
        p.append("goal " + (profile.goal ?? "not set"))
        p.append("days a week " + (profile.daysPerWeek.map(String.init) ?? "not set"))
        p.append("equipment " + (profile.equipment ?? "none stated"))
        p.append("limits " + (profile.limits ?? "none stated"))
        return emit("getProfile", status: "Reading your profile…", p.joined(separator: "; "))
    }

    func findSessions(kind: String, minutes: Int, equipment: String?) -> String {
        let mins = max(5, min(minutes, 90))
        let given = equipment?.trimmingCharacters(in: .whitespaces) ?? ""
        let gear = (!given.isEmpty && given.lowercased() != "none") ? given : profile.equipment
        let k = kind.lowercased()
        // "Feeling unwell" today or yesterday removes sessions that list it in avoidIf (rule W4).
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Demo.now) ?? Demo.now
        let unwell = journal.isOn("Feeling unwell", date: Demo.now) || journal.isOn("Feeling unwell", date: yesterday)
        let avoid: Set<String> = unwell ? ["unwell"] : []
        var found = CoachLibrary.find(cap: rules.cap, minutes: mins, equipment: gear,
                                      kind: k == "any" ? nil : k, avoid: avoid, age: health.age, limit: 3)
        if found.isEmpty, k != "any" {
            found = CoachLibrary.find(cap: rules.cap, minutes: mins, equipment: gear, kind: nil,
                                      avoid: avoid, age: health.age, limit: 3)
        }
        for p in found { plans[p.id] = p }
        let out: String
        if found.isEmpty {
            out = "no library session fits (cap \(rules.cap.rawValue)); suggest an easy walk or rest instead"
        } else {
            out = "sessions within cap \(rules.cap.rawValue): " + found.map { p in
                "id \(p.id): \(p.title), \(p.minutes) min, " + p.steps.prefix(4).map(\.name).joined(separator: ", ")
            }.joined(separator: " | ")
        }
        return emit("findSessions", status: "Finding a session that fits today…", out)
    }

    /// A plan returned by `findSessions` this chat, else a library lookup by id within the cap.
    func plan(id: String?) -> CoachPlan? {
        guard let id, !id.isEmpty else { return nil }
        if let p = plans[id] { return p }
        guard let session = CoachLibrary.session(id: id) else { return nil }
        // Only a session the cap allows (the cap is hard, research/v11-05 decision 2).
        return CoachLibrary.find(cap: rules.cap, minutes: session.minMinutes, equipment: profile.equipment,
                                 kind: session.kind, age: health.age).first { $0.id == id }
    }
}

// MARK: - Foundation Models wrappers

#if canImport(FoundationModels)

@available(iOS 26, *)
enum CoachToolbox {
    /// Metric ids the model may ask for (Not-sent ones answer with the NotSent wording).
    static let metricIDs: [String] = MetricID.allCases.map(\.rawValue) + ["vo2Max"]

    static func all(_ ctx: CoachToolContext) -> [any Tool] {
        [GetTodayTool(ctx: ctx), GetMetricTool(ctx: ctx), GetSleepTool(ctx: ctx), GetLoadTool(ctx: ctx),
         GetSignalsTool(ctx: ctx), GetJournalTool(ctx: ctx), GetWeeklyTool(ctx: ctx), GetProfileTool(ctx: ctx),
         FindSessionsTool(ctx: ctx)]
    }
}

@available(iOS 26, *)
struct GetTodayTool: Tool {
    let ctx: CoachToolContext
    let name = "getToday"
    let description = "Today: recovery %, sleep score, strain vs target, stress, steps, workouts, sync age."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getToday() }
    }
}

@available(iOS 26, *)
struct GetMetricTool: Tool {
    let ctx: CoachToolContext
    let name = "getMetric"
    let description = "One metric vs the user's normal: latest, usual range, status, trend, recent days."
    @Generable struct Arguments {
        @Guide(description: "Metric id", .anyOf(["restingHR", "hrv", "sleepingHR", "breathing", "spo2", "skinTemp",
                                                "sleepTotal", "deepSleep", "remSleep", "awake", "steps", "energy",
                                                "workoutMinutes", "vo2Max"]))
        var metric: String
        @Guide(description: "Days of history", .range(3...14))
        var days: Int
    }
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getMetric(arguments.metric, days: arguments.days) }
    }
}

@available(iOS 26, *)
struct GetSleepTool: Tool {
    let ctx: CoachToolContext
    let name = "getSleep"
    let description = "Last night's sleep and stages, 7-night sleep debt, bedtime consistency, recent nights."
    @Generable struct Arguments {
        @Guide(description: "Nights to list", .range(1...14))
        var nights: Int
    }
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getSleep(nights: arguments.nights) }
    }
}

@available(iOS 26, *)
struct GetLoadTool: Tool {
    let ctx: CoachToolContext
    let name = "getLoad"
    let description = "Training load: daily recovery, strain and sleep, weekly workout minutes, zone minutes."
    @Generable struct Arguments {
        @Guide(description: "Days to list", .range(3...14))
        var days: Int
    }
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getLoad(days: arguments.days) }
    }
}

@available(iOS 26, *)
struct GetSignalsTool: Tool {
    let ctx: CoachToolContext
    let name = "getSignals"
    let description = "Rules that fired today and the intensity cap. Call before any training advice."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getSignals() }
    }
}

@available(iOS 26, *)
struct GetJournalTool: Tool {
    let ctx: CoachToolContext
    let name = "getJournal"
    let description = "Journal tags by day (alcohol, late meal, stress…) and discoveries."
    @Generable struct Arguments {
        @Guide(description: "Days back", .range(1...7))
        var days: Int
    }
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getJournal(days: arguments.days) }
    }
}

@available(iOS 26, *)
struct GetWeeklyTool: Tool {
    let ctx: CoachToolContext
    let name = "getWeekly"
    let description = "This week's averages: recovery, sleep, debt, steps, workout minutes, best and worst trend."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getWeekly() }
    }
}

@available(iOS 26, *)
struct GetProfileTool: Tool {
    let ctx: CoachToolContext
    let name = "getProfile"
    let description = "Age, max HR, heart rate zones in bpm, goal, days a week, equipment, limits."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { ctx.getProfile() }
    }
}

@available(iOS 26, *)
struct FindSessionsTool: Tool {
    let ctx: CoachToolContext
    let name = "findSessions"
    let description = "Reviewed workouts and routines within today's cap. The only source of exercises."
    @Generable struct Arguments {
        @Guide(description: "Kind", .anyOf(["any", "cardio", "run", "walk", "ride", "strength", "intervals", "mobility",
                                           "breathing", "recovery", "winddown"]))
        var kind: String
        @Guide(description: "Minutes available", .range(5...60))
        var minutes: Int
        @Guide(description: "Equipment, or none")
        var equipment: String
    }
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            ctx.findSessions(kind: arguments.kind, minutes: arguments.minutes, equipment: arguments.equipment)
        }
    }
}

#endif
