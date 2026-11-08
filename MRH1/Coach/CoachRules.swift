import Foundation

// v1.1 Coach · rules engine (DESIGN_SPEC_v1.1 §5 §8, research/v11-05 Rules, v11-01 decisions 8, 9, 19, 20). Owner: agent K.
// Pure Swift, no model, no network. Rules decide; the model (or the template coach below) only explains.

/// One fired rule, for `getSignals` and explanations. `id` is the stable rule id ("R1", "W1", "S-a", "L2", …).
struct CoachSignal: Identifiable, Hashable {
    let id: String
    /// One plain sentence with pre-formatted numbers.
    let text: String
    let metrics: [MetricID]
    /// Cap this rule imposes, nil = none.
    let cap: IntensityCap?
}

@MainActor
enum CoachRules {

    // MARK: - Public API

    /// Runs R1–R7, W1–W5, S-a–S-e, L1–L5 plus the rest limits and gentle mode.
    /// `fired` = stable rule ids, `cap` = hard intensity cap, `note` = the one proactive Today card (or nil).
    static func evaluate(_ health: HealthStore, journal: JournalStore) -> CoachRuleResult {
        let ctx = Context(health, journal)
        let fired = run(ctx)
        let cap = fired.reduce(IntensityCap.any) { acc, f in f.signal.cap.map { acc.capped(at: $0) } ?? acc }
        if fired.contains(where: { $0.restDay }) { Memory.markRest(ctx.dayKey) } else { Memory.unmarkRest(ctx.dayKey) }
        let note = pickNote(fired, ctx: ctx)
        return CoachRuleResult(fired: fired.map(\.signal.id), cap: cap, note: note)
    }


    /// Fired rules with their sentences (for the `getSignals` tool).
    static func signals(_ health: HealthStore, journal: JournalStore) -> [CoachSignal] {
        run(Context(health, journal)).map(\.signal)
    }

    /// True for notes that come from a "Watch" signal or rest rule ("Important only" proactivity setting).
    static func isImportant(_ note: CoachNote) -> Bool {
        let rule = note.id.split(separator: ".").first.map(String.init) ?? ""
        return importantRules.contains(rule)
    }

    /// Four data-generated starter questions: Recovery, Sleep, Strain, Plan.
    static func starters(health: HealthStore) -> [String] {
        let hour = Calendar.current.component(.hour, from: Demo.now)
        let recovery: String = {
            guard let r = health.recovery else { return "What is recovery?" }
            if r.score < 34 { return "Why is recovery low?" }
            if r.score >= 67 { return "Why is recovery high?" }
            return "What affects my recovery?"
        }()
        let sleep: String = {
            guard let s = health.lastSleep else { return "Help me sleep better" }
            if s.asleepMinutes < 420 || (health.sleepScore ?? 100) < 70 { return "Why was sleep poor?" }
            return hour >= 18 ? "Help me sleep better" : "How did I sleep?"
        }()
        let strain: String = {
            let t = Scores.strainTarget(health.recovery)
            if let v = health.strain?.value, v >= t.upperBound { return "Done enough today?" }
            return "How hard today?"
        }()
        let plan: String = {
            if hour >= 20 { return "Wind-down routine" }
            let cap = evaluateCapOnly(health)
            return cap == .rest ? "Plan a rest day" : "Plan my workout"
        }()
        return [recovery, sleep, strain, plan]
    }

    /// Rule-based coach reply (used when the on-device model is unavailable, and as the validator fallback).
    static func templateReply(for question: String, metric: MetricID?, health: HealthStore, journal: JournalStore) -> CoachReply {
        let ctx = Context(health, journal)
        let fired = run(ctx)
        let cap = fired.reduce(IntensityCap.any) { acc, f in f.signal.cap.map { acc.capped(at: $0) } ?? acc }
        let t = Template(ctx: ctx, fired: fired, cap: cap)
        var reply = t.answer(question, metric: metric)
        reply.isTemplate = true
        reply.isSample = health.isDemo
        reply.chips = Self.cleanChips(reply.chips)
        reply.headline = Self.limitWords(reply.headline, 14)
        return reply
    }

    // MARK: - Rule ids

    static let importantRules: Set<String> = ["W1", "W2", "W3", "W4", "R1", "R5", "REST-DEBT", "REST-LIMIT"]

    // MARK: - Context (all inputs read once from the HealthStore snapshot)

    @MainActor fileprivate struct Context {
        let health: HealthStore
        let journal: JournalStore
        let now: Date
        let cal = Calendar.current
        let today: Date
        let dayKey: String
        let recovery: RecoveryResult?
        let target: ClosedRange<Double>
        let strainNow: Double?
        let zoneMinutes: [Double]
        let debt: Double
        let spread: Double?
        let lastSleep: SleepSession?
        let sleepScore: Int?
        let history: [DaySummary]
        let tagsToday: Set<String>
        let tagsYesterday: Set<String>
        let unwell: Bool
        let gentle: Bool
        let gentleTag: String?
        let age: Int?

        init(_ health: HealthStore, _ journal: JournalStore) {
            self.health = health
            self.journal = journal
            now = Demo.now
            today = Calendar.current.startOfDay(for: now)
            dayKey = Memory.key(now)
            recovery = health.recovery
            target = Scores.strainTarget(health.recovery)
            strainNow = health.strain?.value
            zoneMinutes = health.strain?.zoneMinutes ?? []
            debt = Insights.sleepDebt(health.recentNights)
            spread = Insights.bedtimeSpread(health.recentNights)
            lastSleep = health.lastSleep
            sleepScore = health.sleepScore
            history = health.history
            tagsToday = journal.entries(for: now)
            let yday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            tagsYesterday = journal.entries(for: yday)
            let both = tagsToday.union(tagsYesterday).map { $0.lowercased() }
            unwell = both.contains { $0 == "feeling unwell" || $0 == "sick" || $0 == "ill" || $0 == "unwell" }
            let gentleWords = ["travel", "vacation", "holiday", "sick", "feeling unwell", "unwell"]
            gentleTag = both.first { gentleWords.contains($0) }
            gentle = gentleTag != nil
            age = health.age
        }

        func state(_ id: MetricID) -> MetricState { health.state(id) }

        /// Strain of the day `ago` days before today (history is oldest first, today last).
        func strain(daysAgo ago: Int) -> Double? {
            guard let d = cal.date(byAdding: .day, value: -ago, to: today) else { return nil }
            return history.first { cal.isDate($0.date, inSameDayAs: d) }?.strain
        }

        func isRecent(_ d: Date?, days: Int = 1) -> Bool {
            guard let d else { return false }
            let diff = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: today).day ?? 99
            return diff <= days
        }

        var asleep: Double? { lastSleep.map(\.asleepMinutes) }
        var hour: Int { cal.component(.hour, from: now) }

        /// Usual bedtime as minutes after midnight (from the last 14 nights).
        var usualBedtime: Int? {
            let nights = health.recentNights.suffix(14)
            guard nights.count >= 3 else { return nil }
            let mins = nights.map { n -> Int in
                let c = cal.dateComponents([.hour, .minute], from: n.start)
                return ((c.hour ?? 0) * 60 + (c.minute ?? 0) - 18 * 60 + 1440) % 1440
            }
            let mean = mins.reduce(0, +) / mins.count
            return (mean + 18 * 60) % 1440
        }

        var stepGoal: ClosedRange<Int> { (age ?? 0) >= 60 ? 6000...8000 : 8000...10000 }
    }

    // MARK: - Fired rule (internal)

    fileprivate struct Draft {
        let headline: String
        let body: String
        let metric: MetricID?
        let chips: [String]
        /// Repetition key: rule + metric + direction (decision 19).
        let key: String
    }

    fileprivate struct Fired {
        let signal: CoachSignal
        var note: Draft?
        /// Counts toward "never more than 2 rest days running".
        var restDay = false
    }

    // MARK: - Rules

    fileprivate static func run(_ c: Context) -> [Fired] {
        var out: [Fired] = []
        func add(_ id: String, _ text: String, _ metrics: [MetricID] = [], cap: IntensityCap? = nil,
                 note: Draft? = nil, restDay: Bool = false) {
            out.append(Fired(signal: CoachSignal(id: id, text: text, metrics: metrics, cap: cap), note: note, restDay: restDay))
        }
        let debtText = fmtMin(c.debt)
        let yHard = (c.strain(daysAgo: 1) ?? 0) >= 14
        let rhr = c.state(.restingHR)

        // ---- Watch signals first (W1/W2 feed the rest decision) ----
        var w1 = false
        var w1Text = ""
        let rs = rhr.series
        if rs.count >= 5, let last = rs.last, c.isRecent(last.date) {
            let last2 = Array(rs.suffix(2))
            let base = rs.dropLast(2).map(\.value)
            let mean = base.reduce(0, +) / Double(base.count)
            let consecutive = (c.cal.dateComponents([.day], from: last2[0].date, to: last2[1].date).day ?? 0) == 1
            if base.count >= 3, consecutive, last2.allSatisfy({ $0.value >= mean + 5 }) {
                w1 = true
                w1Text = "Resting heart rate \(fmt0(last2[0].value)) and \(fmt0(last2[1].value)) bpm, your normal about \(fmt0(mean))."
                add("W1", w1Text + " Two nights in a row at 5+ bpm above.", [.restingHR], cap: .easy,
                    note: Draft(headline: "Resting heart rate is up 2 nights in a row.",
                                body: "\(fmt0(last.value)) bpm vs your usual \(fmt0(mean)). Keep today easy, drink water and aim for an early night. Alcohol, heat, travel or a coming cold can do this.",
                                metric: .restingHR,
                                chips: ["Why is RHR up?", "Should I train today?", "What helps today?"],
                                key: "W1.restingHR.up"))
            }
        }
        let br = c.state(.breathing)
        if w1, let v = br.latest?.value, let b = br.baseline, c.isRecent(br.latest?.date), v >= b.mean + 1.0 {
            let red = (c.recovery?.score ?? 100) < 34
            add("W2", "2 signals are outside your usual range: resting HR and breathing \(br.valueText) /min (normal \(br.yourRangeText)).",
                [.restingHR, .breathing], cap: red ? .rest : .easy,
                note: Draft(headline: "2 signals are outside your usual range.",
                            body: "Resting HR \(rhr.valueText) bpm and breathing \(br.valueText) /min are both above your normal. "
                                + (red ? "Make today a rest day and get extra sleep." : "Keep today easy and get extra sleep."),
                            metric: .breathing,
                            chips: ["Why are both up?", red ? "Plan a rest day" : "Plan an easy session", "What helps today?"],
                            key: "W2.breathing.up"),
                restDay: red)
        }
        let spo2 = c.state(.spo2)
        let week = spo2.series.filter { (c.cal.dateComponents([.day], from: $0.date, to: c.today).day ?? 99) < 7 }
        let under93 = week.filter { $0.value < 93 }.count
        let under90 = week.contains { $0.value < 90 }
        if under93 >= 3 || under90 {
            let text = under90
                ? "A night under 90 % blood oxygen. Under 90 %: see a doctor."
                : "Blood oxygen under 93 % on \(under93) of the last 7 nights."
            add("W3", text, [.spo2],
                note: Draft(headline: under90 ? "Blood oxygen went under 90 % on a night." : "Blood oxygen was under 93 % on \(under93) of 7 nights.",
                            body: under90
                                ? "Under 90 % is a reason to see a doctor. Band fit and altitude can affect the reading."
                                : "Band fit and altitude can affect it. It’s worth asking a doctor about.",
                            metric: .spo2,
                            chips: ["What is blood oxygen?", "Show my last nights", "How to wear it?"],
                            key: "W3.spo2.low"))
        }
        if c.unwell {
            add("W4", "You tagged feeling unwell. Neck check: above-the-neck symptoms only, light movement. Fever, chest symptoms or aches, rest.",
                [], cap: .rest,
                note: Draft(headline: "You tagged feeling unwell: light movement only today.",
                            body: "With only above-the-neck symptoms, an easy walk is fine. With fever, chest symptoms or aches, rest fully. Training targets are paused.",
                            metric: nil,
                            chips: ["Plan a rest day", "When to train again?", "What helps recovery?"],
                            key: "W4.unwell"))
        }
        let tense = c.health.stressHours.filter { ($0.level ?? 0) >= 2 }.count
        if tense >= 3 {
            add("W5", "Stress was high for \(tense) hours today while you were still.", [],
                note: Draft(headline: "Stress ran high for \(tense) hours while you were still.",
                            body: "Five minutes of slow breathing with long exhales often settles your heart rate. Try it now or before bed.",
                            metric: nil,
                            chips: ["Calm me down", "Why does breathing help?", "What raised my stress?"],
                            key: "W5.stress.high"))
        }

        // ---- Readiness / intensity ----
        let restLimit = Memory.restDaysBefore(c.today) >= 2
        if let r = c.recovery {
            if r.score < 34 {
                if c.debt > 300 {
                    if restLimit {
                        add("REST-LIMIT", "Third low day running: offer light movement instead of rest.", [.sleepTotal], cap: .easy,
                            note: Draft(headline: "Third low day: light movement helps more than rest.",
                                        body: "Recovery is \(r.score) % and sleep debt \(debtText). A 20-min easy walk or 10 min of mobility keeps you moving without adding load.",
                                        metric: nil,
                                        chips: ["Plan an easy walk", "Why is recovery low?", "Help me sleep better"],
                                        key: "R1.recovery.low"))
                        add("R1", "Recovery \(r.score) % with sleep debt \(debtText): rest, an easy walk or Zone 1–2 under 30 min, plus mobility.",
                            [.sleepTotal], cap: .easy)
                    } else {
                        add("R1", "Recovery \(r.score) % with sleep debt \(debtText): rest, an easy walk or Zone 1–2 under 30 min, plus mobility.",
                            [.sleepTotal], cap: .rest,
                            note: Draft(headline: "Recovery \(r.score) % and \(debtText) short on sleep: rest day.",
                                        body: "Pick rest, an easy walk under 30 min, or 10 min of mobility. An earlier night tonight will help most.",
                                        metric: .sleepTotal,
                                        chips: ["Plan a rest day", "Why is recovery low?", "Help me sleep better"],
                                        key: "R1.recovery.low"),
                            restDay: true)
                    }
                } else {
                    add("R2", "Recovery \(r.score) %: Zone 1–2 up to 45 min, no intervals. Strength with 2+ reps in reserve.", [], cap: .easy)
                }
            } else if r.score < 67 {
                add("R3", "Recovery \(r.score) %: steady Zone 2 or technique and strength work, at most one short Zone 3 block. Aim for strain \(fmtRange(c.target)).",
                    [], cap: .moderate)
            } else if !yHard {
                add("R4", "Recovery \(r.score) % after an easy day: intervals in Zone 4–5 fit, aiming for strain \(fmtRange(c.target)).", [], cap: .any,
                    note: c.gentle ? nil : Draft(headline: "Green light: a hard session fits today.",
                                                 body: "Recovery \(r.score) % and yesterday was easy. Intervals in Zone 4–5 fit, aiming for strain \(fmtRange(c.target)).",
                                                 metric: nil,
                                                 chips: ["Plan a hard session", "What are my zones?", "How hard today?"],
                                                 key: "R4.recovery.high"))
            } else {
                add("R4", "Recovery \(r.score) % but yesterday was hard: steady work today, no intervals.", [], cap: .moderate)
            }
        } else {
            let early = rhr.earlyReadText ?? "Early read: \(rhr.baselineDays) of \(MetricState.fullBaselineDays) baseline days."
            add("R7", "No recovery score yet. Keep it general and moderate. \(early)", [.restingHR], cap: .moderate)
        }
        if let a = c.strain(daysAgo: 1), let b = c.strain(daysAgo: 2), a >= 14, b >= 14 {
            add("R5", "Two hard days in a row (strain \(fmt1(b)) and \(fmt1(a))): today is easy.", [], cap: .easy,
                note: Draft(headline: "Two hard days in a row: keep today easy.",
                            body: "Strain was \(fmt1(b)) and then \(fmt1(a)). An easy day now lets that work pay off. Zone 1–2 or mobility only.",
                            metric: nil,
                            chips: ["Plan an easy session", "Why go easy today?", "Plan my week"],
                            key: "R5.strain.high"))
        }
        if let s = c.strainNow, s >= c.target.upperBound {
            add("R6", "Target reached: strain \(fmt1(s)) of \(fmtRange(c.target)). A cool-down or walk only.", [], cap: .rest)
        }
        // Rest suggestion rule 2 (DESIGN_SPEC_v1.1 §5): sleep debt ≥ 2 h with strain above target.
        if let s = c.strainNow, c.debt >= 120, s > c.target.upperBound {
            if restLimit {
                if !out.contains(where: { $0.signal.id == "REST-LIMIT" }) {
                    add("REST-LIMIT", "Third rest day running: offer light movement instead.", [], cap: .easy)
                }
            } else {
                add("REST-DEBT", "Sleep debt \(debtText) and strain \(fmt1(s)) above the \(fmtRange(c.target)) target: rest for the rest of today.",
                    [.sleepTotal], cap: .rest,
                    note: Draft(headline: "Sleep debt \(debtText) and strain above target: rest now.",
                                body: "Strain is \(fmt1(s)) against a \(fmtRange(c.target)) target. Stop here, stretch for 10 min and go to bed earlier tonight.",
                                metric: .sleepTotal,
                                chips: ["Plan a rest day", "Help me sleep better", "Explain my strain"],
                                key: "REST-DEBT.strain.high"),
                    restDay: true)
            }
        }

        // ---- Sleep ----
        if let a = c.asleep, c.health.isSleepFresh, a < 420 {
            let short = a <= 360
            add("S-a", "Last night \(fmtMin(a)) asleep, under the 7 h floor" + (short ? ": short, keep training easy." : "."),
                [.sleepTotal], cap: short ? .easy : nil,
                note: short
                    ? Draft(headline: "Short night: \(fmtMin(a)) asleep, under 6 h.",
                            body: "Keep training to Zone 1–2 today, and protect tonight’s bedtime.",
                            metric: .sleepTotal,
                            chips: ["Why was sleep poor?", "Plan an easy session", "Is a nap OK?"],
                            key: "S-a.sleepTotal.low")
                    : Draft(headline: "\(fmtMin(a)) asleep: under 7 h for the night.",
                            body: "Aim to be in bed 30 min earlier tonight. That beats sleeping in at the weekend.",
                            metric: .sleepTotal,
                            chips: ["Why was sleep poor?", "Help me sleep better", "Is a nap OK?"],
                            key: "S-a.sleepTotal.low"))
        }
        if let sp = c.spread, sp > 45 {
            add("S-b", "Bedtime varies by ±\(Int(sp.rounded())) min (consistency \(Insights.consistencyScore(sp))). Keep bedtime within 30 min.",
                [.sleepTotal],
                note: Draft(headline: "Bedtime varies by ±\(Int(sp.rounded())) min: keep it within 30.",
                            body: "A regular bedtime matters more than a long lie-in. Pick a time you can hold this week, give or take 30 min.",
                            metric: .sleepTotal,
                            chips: ["Help me sleep better", "Why does regularity matter?", "Wind-down routine"],
                            key: "S-b.bedtime.spread"))
        }
        let caffeineFinding = c.journal.discoveries.first { $0.lowercased().contains("caffeine") && $0.contains("sleep score") && $0.contains("lower") }
        let caffeineLast = c.tagsYesterday.contains("Caffeine after 2 pm")
        let poorNight = Double(c.sleepScore ?? 100) < (avgSleepScore(c.history) ?? 0) - 3
        if caffeineFinding != nil || (caffeineLast && poorNight) {
            let cutoff = c.usualBedtime.map { clock(($0 - 8 * 60 + 1440) % 1440) }
            add("S-c", (caffeineFinding ?? "You tagged caffeine after 2 pm before a lower sleep score.") + " Caffeine cut-off: 8 h before bed" + (cutoff.map { ", about \($0)." } ?? "."),
                [.sleepTotal],
                note: Draft(headline: "Caffeine after 2 pm lines up with lower sleep scores.",
                            body: (cutoff.map { "Try a cut-off 8 h before bed, about \($0) for your usual bedtime." } ?? "Try a cut-off 8 h before bed.")
                                + " Its effect on sleep often goes unnoticed.",
                            metric: .sleepTotal,
                            chips: ["Help me sleep better", "What do tags show?", "Wind-down routine"],
                            key: "S-c.caffeine"))
        }
        let culprit = ["Alcohol", "Late meal"].first { c.tagsYesterday.contains($0) }
        if let tag = culprit {
            for id in [MetricID.deepSleep, .remSleep] {
                let s = c.state(id)
                if let v = s.latest, c.cal.isDate(v.date, inSameDayAs: c.today), let b = s.baseline, v.value < b.low {
                    let lost = Int((b.mean - v.value).rounded())
                    let stage = id == .deepSleep ? "Deep" : "REM"
                    add("S-d", "\(stage) sleep \(lost) min under your usual after a night tagged \(tag.lowercased()).", [id],
                        note: Draft(headline: "\(stage) sleep \(lost) min under your usual after \(tag.lowercased()).",
                                    body: tag == "Alcohol"
                                        ? "Alcohol often cuts REM and deep sleep first. An alcohol-free evening before key days helps."
                                        : "A late meal often cuts deep sleep. Try to finish eating 3 h before bed.",
                                    metric: id,
                                    chips: ["What do tags show?", "Help me sleep better", "Why was sleep poor?"],
                                    key: "S-d.\(id.rawValue).\(tag)"))
                    break
                }
            }
        }
        if c.debt > 300 {
            add("S-e", "Sleep debt \(debtText) over 7 nights: one earlier night (+30–45 min), not a long lie-in.", [.sleepTotal],
                note: Draft(headline: "Sleep debt \(debtText) this week: try one earlier night.",
                            body: "Go to bed 30–45 min earlier tonight rather than sleeping in. Long lie-ins shift your body clock.",
                            metric: .sleepTotal,
                            chips: ["Pay back sleep debt", "Is a nap OK?", "Wind-down routine"],
                            key: "S-e.debt"))
        }

        // ---- Load and weekly volume (no goals in gentle mode) ----
        let wm = c.state(.workoutMinutes)
        if !c.gentle, let latest = wm.latest?.value, !wm.series.isEmpty {
            let m = Int(latest.rounded())
            if m < 150 {
                add("L1", "\(m) min of workouts in 7 days: \(150 - m) min to the 150 a week guideline.", [.workoutMinutes],
                    note: m == 0 ? nil : Draft(headline: "\(150 - m) min to the 150-minute weekly guideline.",
                                               body: "You logged \(m) min of workouts in 7 days. Two easy 30-min sessions would get you most of the way.",
                                               metric: .workoutMinutes,
                                               chips: ["Plan my workout", "Plan my week", "Does walking count?"],
                                               key: "L1.workoutMinutes.low"))
            } else if m >= 300 {
                add("L1", "\(m) min of workouts in 7 days: well above the 150 guideline. Watch the recovery trend.", [.workoutMinutes],
                    note: Draft(headline: "\(m) workout minutes this week: well past 150.",
                                body: "A strong week. Keep an eye on recovery" + (c.recovery.map { ": it’s \($0.score) % today." } ?? "."),
                                metric: .workoutMinutes,
                                chips: ["Training too much?", "Weekly review", "Plan a rest day"],
                                key: "L1.workoutMinutes.high"))
            }
            let v = wm.series.map(\.value)
            if v.count >= 29 {
                let n = v.count - 1
                let prior = [v[n - 7], v[n - 14], v[n - 21], v[n - 28]]
                let chronic = prior.reduce(0, +) / 4
                if chronic >= 30, latest / chronic > 1.5 {
                    add("L2", "Big jump vs your usual week: \(m) min vs about \(Int(chronic.rounded())) a week before. Ease in.", [.workoutMinutes],
                        note: Draft(headline: "Big jump vs your usual week: ease in.",
                                    body: "\(m) min in 7 days vs about \(Int(chronic.rounded())) a week before. Keep the next sessions easy while your body adapts.",
                                    metric: .workoutMinutes,
                                    chips: ["Training too much?", "Plan an easy session", "Weekly review"],
                                    key: "L2.load.up"))
                }
            }
            // L4: workout names exist for today only, so we can only be sure when no workout was logged in 7 days.
            if m == 0, !c.health.todayWorkouts.contains(where: { $0.name == "Strength" }) {
                add("L4", "No workouts logged in the last 7 days, so no strength either: suggest 2 short strength sessions this week.", [.workoutMinutes],
                    note: Draft(headline: "No workouts logged this week: try 2 short strength sessions.",
                                body: "Two 20-min sessions a week keep your muscles strong. No gear needed, and the first can be today.",
                                metric: .workoutMinutes,
                                chips: ["Quick strength, no gear", "Plan my week", "Why strength training?"],
                                key: "L4.strength"))
            }
        }
        // L3: zone mix, today's training only (HealthStore keeps zone minutes for today).
        let trained = c.health.todayWorkouts.contains { !$0.isWalk }
        if trained, c.zoneMinutes.count == 5 {
            let z3 = c.zoneMinutes[2], z12 = c.zoneMinutes[0] + c.zoneMinutes[1]
            if z3 >= 20, z3 > z12 {
                add("L3", "Today’s training sat mostly in Zone 3 (\(Int(z3.rounded())) min vs \(Int(z12.rounded())) in Zones 1–2).", [],
                    note: Draft(headline: "Today’s effort sat mostly in Zone 3.",
                                body: "\(Int(z3.rounded())) min in Zone 3 vs \(Int(z12.rounded())) in Zones 1–2. Make your next session truly easy, at a pace you could chat at.",
                                metric: nil,
                                chips: ["What are my zones?", "Plan an easy session", "Explain my strain"],
                                key: "L3.zone3"))
            }
        }
        let steps = c.state(.steps)
        if !c.gentle, let y = steps.latest, c.isRecent(y.date), y.value < 5000 {
            let goal = c.stepGoal
            add("L5", "Yesterday \(MetricID.steps.format(y.value)) steps, under 5,000. Goal range \(goal.lowerBound.formatted())–\(goal.upperBound.formatted()).", [.steps],
                note: Draft(headline: "Yesterday was \(MetricID.steps.format(y.value)) steps: a walk would help today.",
                            body: "A good range for you is \(goal.lowerBound.formatted())–\(goal.upperBound.formatted()) a day. A 15-min walk adds about 1,500.",
                            metric: .steps,
                            chips: ["Plan a walk", "What’s my step goal?", "Walk more"],
                            key: "L5.steps.low"))
        }

        // ---- Gentle mode (travel / vacation / sick tags): no strain targets, cap at moderate ----
        if c.gentle, let tag = c.gentleTag {
            add("GENTLE", "Gentle mode (tag: \(tag)): no strain targets, steady effort at most.", [], cap: .moderate,
                note: c.unwell ? nil : Draft(headline: "Tagged \(tag): no strain targets for now.",
                                             body: "Move when it feels good: a walk to explore or a short mobility session. Keep a regular bedtime where you can.",
                                             metric: nil,
                                             chips: ["Plan an easy walk", "Help me sleep better", "Desk mobility"],
                                             key: "GENTLE.\(tag)"))
        }
        return out
    }

    // MARK: - Note selection (1 at a time, ≤ 3 a day, repetition guard, never restate a chart)

    private enum Slot: String { case morning, workout, evening }

    private static func pickNote(_ fired: [Fired], ctx c: Context) -> CoachNote? {
        // Proactive notes setting (Menu → Coach): off · important · daily (default, morning card kept all day) · every (3 slots).
        let mode = UserDefaults.standard.string(forKey: "coach.proactive") ?? "daily"
        if mode == "off" { return nil }
        let slot: Slot = {
            if mode == "daily" { return .morning }
            if c.hour >= 20 { return .evening }
            let recentWorkout = c.health.todayWorkouts.contains { w in
                !w.isWalk && c.now.timeIntervalSince(w.start.addingTimeInterval(w.minutes * 60)) < 3 * 3600
                    && c.now >= w.start
            }
            return recentWorkout ? .workout : .morning
        }()
        let morning = ["W3", "W4", "W2", "W1", "REST-LIMIT", "R1", "REST-DEBT", "R5", "S-a", "S-d", "S-c", "L2", "GENTLE", "R4", "L5", "L4", "S-b", "S-e", "L1", "W5", "L3"]
        let workout = ["W4", "W2", "REST-DEBT", "L3", "L2", "R5", "W1", "L1", "W5", "S-e", "S-b"]
        let evening = ["W3", "W4", "W2", "W1", "REST-DEBT", "W5", "S-b", "S-c", "S-e", "S-d", "S-a", "L4", "GENTLE"]
        let order = slot == .evening ? evening : (slot == .workout ? workout : morning)

        let withNotes = fired.filter { $0.note != nil && (mode != "important" || importantRules.contains($0.signal.id)) }
        for id in order {
            guard let f = withNotes.first(where: { $0.signal.id == id }), let d = f.note else { continue }
            // Decision 19: same observation at most once in 3 days (but keep showing it on the day it was raised).
            if let last = Memory.lastShown(d.key), last != c.dayKey, Memory.daysBetween(last, c.dayKey) < 3 { continue }
            let noteID = "\(id).\(slot.rawValue).\(c.dayKey)"
            // At most 3 different notes a day.
            let shownToday = Memory.notesShown(on: c.dayKey)
            if !shownToday.contains(noteID), shownToday.count >= 3 { return nil }
            Memory.recordNote(noteID, key: d.key, day: c.dayKey)
            return CoachNote(id: noteID, headline: limitWords(d.headline, 14),
                             body: fitBody(headline: d.headline, body: d.body, limit: 40),
                             metric: d.metric, chips: cleanChips(d.chips))
        }
        return nil
    }

    /// Cap only (used by starters; no note bookkeeping).
    private static func evaluateCapOnly(_ health: HealthStore) -> IntensityCap {
        guard let journal = JournalStore.current else { return .moderate }
        return run(Context(health, journal)).reduce(IntensityCap.any) { acc, f in f.signal.cap.map { acc.capped(at: $0) } ?? acc }
    }

    // MARK: - Copy helpers

    static func words(_ s: String) -> Int { s.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }

    static func limitWords(_ s: String, _ n: Int) -> String {
        let w = s.split(separator: " ")
        guard w.count > n else { return s }
        return w.prefix(n).joined(separator: " ")
    }

    /// Drops trailing sentences until headline + body fit `limit` words.
    static func fitBody(headline: String, body: String, limit: Int) -> String {
        var sentences = body.components(separatedBy: ". ").map { $0.hasSuffix(".") ? $0 : $0 + "." }
        while sentences.count > 1, words(headline) + words(sentences.joined(separator: " ")) > limit { sentences.removeLast() }
        var out = sentences.joined(separator: " ")
        if out.hasSuffix("..") { out.removeLast() }
        return out
    }

    /// Exactly 3 chips, each ≤ 4 words, no duplicates; pads with safe defaults.
    static func cleanChips(_ chips: [String]) -> [String] {
        var out: [String] = []
        for c in chips + ["Plan my workout", "Weekly review", "Help me sleep better", "What can you see?"] {
            let t = c.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, words(t) <= 4, !out.contains(t) else { continue }
            out.append(t)
            if out.count == 3 { break }
        }
        return out
    }

    fileprivate static func fmt0(_ v: Double) -> String { String(format: "%.0f", locale: .current, v) }
    fileprivate static func fmt1(_ v: Double) -> String { String(format: "%.1f", locale: .current, v) }
    fileprivate static func fmtRange(_ r: ClosedRange<Double>) -> String { "\(fmt0(r.lowerBound))–\(fmt0(r.upperBound))" }
    fileprivate static func fmtMin(_ m: Double) -> String { MetricID.sleepTotal.format(m) }
    fileprivate static func clock(_ minutesAfterMidnight: Int) -> String {
        var c = DateComponents()
        c.hour = minutesAfterMidnight / 60
        c.minute = (minutesAfterMidnight % 60) / 15 * 15
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
    fileprivate static func avgSleepScore(_ h: [DaySummary]) -> Double? {
        let xs = h.dropLast().compactMap(\.sleepScore)
        return xs.isEmpty ? nil : Double(xs.reduce(0, +)) / Double(xs.count)
    }

    // MARK: - Memory (rest-day streak, repetition guard, daily note count). In memory only in demo mode.

    @MainActor fileprivate enum Memory {
        private static let restKey = "mrh1.coach.restDays"
        private static let shownKey = "mrh1.coach.noteShown"
        private static let dayNotesKey = "mrh1.coach.dayNotes"
        @MainActor private static var mem: [String: Any] = [:]

        private static let fmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.calendar = Calendar(identifier: .gregorian)
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()

        static func key(_ d: Date) -> String { fmt.string(from: d) }
        static func daysBetween(_ a: String, _ b: String) -> Int {
            guard let x = fmt.date(from: a), let y = fmt.date(from: b) else { return 99 }
            return abs(Calendar.current.dateComponents([.day], from: x, to: y).day ?? 99)
        }

        @MainActor private static func get<T>(_ k: String) -> T? {
            Demo.isOn ? mem[k] as? T : UserDefaults.standard.object(forKey: k) as? T
        }
        @MainActor private static func set(_ v: Any, _ k: String) {
            if Demo.isOn { mem[k] = v } else { UserDefaults.standard.set(v, forKey: k) }
        }

        /// Rest days recorded on the 2 calendar days before `day`.
        @MainActor static func restDaysBefore(_ day: Date) -> Int {
            let days: [String] = get(restKey) ?? []
            return (1...2).filter { ago in
                guard let d = Calendar.current.date(byAdding: .day, value: -ago, to: day) else { return false }
                return days.contains(key(d))
            }.count
        }
        @MainActor static func markRest(_ day: String) {
            var days: [String] = get(restKey) ?? []
            guard !days.contains(day) else { return }
            days.append(day)
            set(Array(days.suffix(14)), restKey)
        }
        @MainActor static func unmarkRest(_ day: String) {
            var days: [String] = get(restKey) ?? []
            guard days.contains(day) else { return }
            days.removeAll { $0 == day }
            set(days, restKey)
        }

        @MainActor static func lastShown(_ noteKey: String) -> String? {
            let m: [String: String] = get(shownKey) ?? [:]
            return m[noteKey]
        }
        @MainActor static func notesShown(on day: String) -> [String] {
            let m: [String: [String]] = get(dayNotesKey) ?? [:]
            return m[day] ?? []
        }
        @MainActor static func recordNote(_ id: String, key noteKey: String, day: String) {
            var shown: [String: String] = get(shownKey) ?? [:]
            if shown[noteKey] != day {
                shown[noteKey] = day
                set(shown.filter { daysBetween($0.value, day) <= 7 }, shownKey)
            }
            var dayNotes: [String: [String]] = get(dayNotesKey) ?? [:]
            if !(dayNotes[day] ?? []).contains(id) {
                dayNotes[day, default: []].append(id)
                set(dayNotes.filter { daysBetween($0.key, day) <= 2 }, dayNotesKey)
            }
        }

        /// Clears all coach-rule memory ("Delete coach history").
        @MainActor static func reset() {
            for k in [restKey, shownKey, dayNotesKey] {
                if Demo.isOn { mem[k] = nil } else { UserDefaults.standard.removeObject(forKey: k) }
            }
        }
    }

    /// Clears rest-day streak and note history (call from "Delete coach history").
    static func resetMemory() { Memory.reset() }

    // MARK: - Template coach

    @MainActor fileprivate struct Template {
        let ctx: Context
        let fired: [Fired]
        let cap: IntensityCap

        var c: Context { ctx }
        func has(_ id: String) -> Bool { fired.contains { $0.signal.id == id } }
        func signal(_ id: String) -> CoachSignal? { fired.first { $0.signal.id == id }?.signal }

        // MARK: Routing

        func answer(_ question: String, metric: MetricID?) -> CoachReply {
            let q = question.lowercased()
            func any(_ words: String...) -> Bool { words.contains { q.contains($0) } }

            if any("can you see", "what coach knows", "what do you know", "what you know", "privacy") { return whatISee() }
            if any("unwell", "sick", "feel ill", "i'm ill", "cold coming", "train again") { return unwell() }
            if any("rest day", "rest-day") { return planReply(q, kind: "recovery", fallbackMinutes: 20) }
            if any("wind-down", "wind down", "winddown") { return planReply(q, kind: "winddown", fallbackMinutes: 10) }
            if any("fall asleep", "breathing only") { return planReply(q, kind: "breath", focus: "sleep", fallbackMinutes: 5) }
            if any("calm", "breath", "another round", "relax") && !any("why does", "why is", "rate") { return planReply(q, kind: "breath", fallbackMinutes: 5) }
            if any("why does breathing", "why it works", "why does it work") { return breathingWhy() }
            if any("mobility", "stretch", "desk", "hips focus", "yoga") { return planReply(q, kind: "mobility", fallbackMinutes: 10) }
            if any("my week", "next week", "fewer days", "add strength", "swap a day") { return planWeek() }
            if any("weekly", "review", "what slipped", "best change", "this week") { return weekly() }
            if any("too much", "deload") { return tooMuch() }
            if any("zones", "zone table", "max hr", "my zones") && !any("plan") { return zones() }
            if any("plan", "workout", "session", "exercise", "shorter", "indoor version", "harder", "easier", "quick strength", "strength") && !any("why strength") {
                return planReply(q, kind: nil, fallbackMinutes: nil)
            }
            if any("why strength") { return strengthWhy() }
            if any("nap") { return nap() }
            if any("debt", "pay back") { return debt() }
            if any("caffeine") { return caffeine() }
            if any("regularity", "bedtime") { return regularity() }
            if let m = metric ?? mentionedMetric(q) { return explain(m, q) }
            if any("sleep better", "help me sleep", "sleep tips") { return sleepBetter() }
            if any("sleep", "slept", "night") { return sleepWhy() }
            if any("recovery", "recover", "should i train", "what helps") { return recovery(q) }
            if any("strain", "how hard", "done enough", "target", "go easy") { return hardness() }
            if any("step", "walk more", "walking count") { return stepsReply(q) }
            if any("tag", "journal", "discover") { return tagsReply() }
            if any("stress") { return stressReply() }
            return today()
        }

        func mentionedMetric(_ q: String) -> MetricID? {
            let map: [(String, MetricID)] = [
                ("rhr", .restingHR), ("resting", .restingHR), ("hrv", .hrv), ("variability", .hrv),
                ("sleeping hr", .sleepingHR), ("heart rate during sleep", .sleepingHR),
                ("breathing rate", .breathing), ("both up", .breathing), ("respirat", .breathing),
                ("oxygen", .spo2), ("spo2", .spo2), ("wear it", .spo2), ("last nights", .spo2),
                ("skin temp", .skinTemp), ("temperature", .skinTemp),
                ("deep", .deepSleep), ("rem", .remSleep), ("awake", .awake), ("wake", .awake),
                ("active energy", .energy), ("calorie", .energy), ("workout time", .workoutMinutes),
            ]
            return map.first { q.contains($0.0) }?.1
        }

        // MARK: Pills

        func pill(_ id: MetricID) -> DataPill {
            let s = c.state(id)
            let label = shortName(id)
            if let miss = s.missing, !s.hasData || miss == .notSent {
                return DataPill(metric: id, text: "\(label) · \(miss.shortText)", tier: nil)
            }
            let unit = id.info.unit.isEmpty || id == .steps ? "" : " " + id.info.unit
            let normal: String = s.baseline.map { b in "normal \(id.format(b.low))–\(id.format(b.high))" } ?? "learning your range"
            return DataPill(metric: id, text: "\(label) \(s.valueText)\(unit) · \(normal)", tier: s.statusTier)
        }

        func sleepPill() -> DataPill? {
            guard let a = c.asleep else { return nil }
            let s = c.state(.sleepTotal)
            let normal = s.baseline.map { "normal \(MetricID.sleepTotal.format($0.low))–\(MetricID.sleepTotal.format($0.high))" } ?? "need 8 h"
            return DataPill(metric: .sleepTotal, text: "Sleep \(fmtMin(a)) · \(normal)", tier: s.statusTier)
        }

        func shortName(_ id: MetricID) -> String {
            switch id {
            case .restingHR: return "RHR"
            case .hrv: return "HRV"
            case .sleepingHR: return "Sleeping HR"
            case .breathing: return "Breathing"
            case .spo2: return "SpO2"
            case .skinTemp: return "Skin temp"
            case .sleepTotal: return "Sleep"
            case .deepSleep: return "Deep"
            case .remSleep: return "REM"
            case .awake: return "Awake"
            case .steps: return "Steps"
            case .energy: return "Active energy"
            case .workoutMinutes: return "Workouts"
            }
        }

        func reply(_ headline: String, _ sentences: [String], pills: [DataPill?] = [], chips: [String], plan: CoachPlan? = nil) -> CoachReply {
            CoachReply(headline: headline,
                       body: sentences.filter { !$0.isEmpty }.prefix(3).joined(separator: " "),
                       pills: Array(pills.compactMap { $0 }.prefix(3)),
                       chips: chips, plan: plan, isTemplate: true)
        }

        var capReason: String {
            if has("W4") { return "You tagged feeling unwell, so light movement only." }
            if has("REST-LIMIT") { return "After two rest days, light movement helps more than more rest." }
            if has("R1") { return "Recovery is \(c.recovery?.score ?? 0) % with sleep debt \(fmtMin(c.debt)), so keep it light." }
            if has("REST-DEBT") { return "Sleep debt \(fmtMin(c.debt)) and strain is above target, so keep it light." }
            if has("R6") { return "You’ve reached today’s strain target, so a cool-down or walk only." }
            if has("W2") { return "2 signals are outside your usual range, so keep it easy." }
            if has("W1") { return "Resting heart rate is up 2 nights running, so keep it easy." }
            if has("R5") { return "Two hard days in a row, so today stays easy." }
            if has("S-a") && cap == .easy { return "A short night, so Zone 1–2 only." }
            if has("R2") { return "Recovery is \(c.recovery?.score ?? 0) %, so Zone 1–2 and no intervals." }
            if has("GENTLE") { return "Gentle mode is on, so no strain targets." }
            if has("R3") { return "Recovery is \(c.recovery?.score ?? 0) %, so steady effort fits." }
            if has("R7") { return "Your baseline is still young, so it stays moderate." }
            if cap == .any, let r = c.recovery { return "Recovery is \(r.score) % after an easy day, so a hard session fits." }
            return "It fits today’s \(cap.plainWord) cap."
        }

        // MARK: Skills

        func today() -> CoachReply {
            var s: [String] = []
            if let r = c.recovery { s.append("Recovery \(r.score) %.") } else { s.append(c.state(.restingHR).earlyReadText ?? "Recovery is still calibrating.") }
            if let sc = c.sleepScore { s.append("Sleep score \(sc).") }
            if let st = c.strainNow { s.append("Strain \(fmt1(st)) so far" + (c.gentle ? "." : ", target \(fmtRange(c.target)).")) }
            return reply(Scores.verdict(c.recovery), [s.joined(separator: " "), capReason],
                         pills: [pill(.restingHR), sleepPill()],
                         chips: [c.recovery.map { $0.score < 34 ? "Why is recovery low?" : "Why is recovery high?" } ?? "What is recovery?",
                                 "Plan my workout", "Help me sleep better"])
        }

        func recovery(_ q: String) -> CoachReply {
            guard let r = c.recovery else {
                let early = c.state(.restingHR).earlyReadText ?? "Recovery needs a few nights of resting heart rate."
                return reply("Recovery is still calibrating.", [early, "Until then, keep training general and moderate."],
                             pills: [pill(.restingHR)], chips: ["Plan my workout", "What can you see?", "How did I sleep?"])
            }
            // E1: the contributor with the most negative z.
            let sorted = r.contributors.sorted { $0.z < $1.z }
            let low = r.score < 50
            let main = low ? sorted.first : sorted.last
            var s: [String] = []
            var pills: [DataPill?] = []
            if let m = main {
                let st = c.state(m.id)
                let normal = m.id == .sleepTotal ? "your need of 8 h" : "your normal \(st.yourRangeText)"
                s.append("\(m.label) \(m.valueText) vs \(normal).")
                pills.append(m.id == .sleepTotal ? sleepPill() : pill(m.id))
            }
            if let tag = c.tagsYesterday.sorted().first, low { s.append("You tagged \(tag.lowercased()) yesterday.") }
            if let sig = r.signalsText { s.append("Based on \(sig): HRV is not sent by Google Health.") }
            for k in r.contributors.map(\.id) where k != main?.id && pills.count < 3 {
                pills.append(k == .sleepTotal ? sleepPill() : pill(k))
            }
            let head: String = {
                guard let m = main else { return "Recovery is \(r.score) %." }
                let name = m.id == .sleepTotal ? "sleep" : m.label.lowercased()
                return low ? "Recovery \(r.score) %: \(name) is the main drag." : "Recovery \(r.score) %: \(name) is helping most."
            }()
            let chips = low ? ["What helps today?", "Plan my workout", "Is this a concern?"]
                            : ["Plan a hard session", "Weekly review", "How hard today?"]
            if q.contains("concern") {
                return reply("This is a wellness score, not a diagnosis.",
                             ["One low day is common after short sleep, alcohol or hard training.", "If you feel unwell for several days, check with a doctor."],
                             pills: pills, chips: ["What helps today?", "Show my last nights", "Plan a rest day"])
            }
            if q.contains("what helps") || q.contains("should i train") {
                return reply(low ? "Today: easy movement, water and an earlier night." : "You can train today.",
                             [capReason, low ? "An earlier bedtime helps tomorrow’s score the most." : ""],
                             pills: pills, chips: ["Plan my workout", "Help me sleep better", "Why is recovery low?"])
            }
            return reply(head, s, pills: pills, chips: chips)
        }

        func explain(_ id: MetricID, _ q: String) -> CoachReply {
            let s = c.state(id)
            let info = id.info
            if !s.hasData || s.missing == .notSent {
                let miss = s.missing ?? .noReading
                let instead = id == .hrv ? "Recovery uses resting HR, breathing and sleep instead." : "Coach works from your other signals instead."
                return reply("\(info.name): \(miss.text).", [instead],
                             pills: [pill(.restingHR)], chips: ["Why is recovery low?", "What can you see?", "Plan my workout"])
            }
            let unit = info.unit.isEmpty || id == .steps ? "" : " " + info.unit
            let dir: String
            switch s.flag {
            case .high: dir = "above your usual range"
            case .low: dir = "below your usual range"
            default: dir = "within your usual range"
            }
            var sentences: [String] = []
            sentences.append(s.baseline != nil ? "Your normal is \(s.yourRangeText)." : (s.earlyReadText ?? s.yourRangeText + "."))
            if s.isConcern {
                let causes = s.flag == .high ? info.ifHigh : info.ifLow
                sentences.append("Possible causes: " + lowerFirst(causes))
                if let tag = c.tagsYesterday.sorted().first { sentences.append("You tagged \(tag.lowercased()) yesterday.") }
            } else if let e = s.earlyReadText, s.baseline != nil {
                sentences.append(e)
            } else {
                sentences.append(lowerFirstSentence(info.what))
            }
            if id == .spo2 && (q.contains("wear") || q.contains("accura")) {
                return reply("Wear the band snug, a finger above the wrist bone.",
                             ["Loose fit and cold hands lower SpO2 readings.", sentences.first ?? ""],
                             pills: [pill(.spo2)], chips: ["What is blood oxygen?", "Show my last nights", "Help me sleep better"])
            }
            let related: [MetricID] = {
                switch id {
                case .restingHR: return [.sleepingHR, .breathing]
                case .breathing: return [.restingHR]
                case .deepSleep, .remSleep, .awake: return [.sleepTotal]
                case .sleepingHR: return [.restingHR]
                default: return []
                }
            }()
            let short = shortName(id)
            let chips: [String] = {
                switch id {
                case .restingHR: return ["Should I train today?", "Show 30 days", "What helps today?"]
                case .spo2: return ["How to wear it?", "Show my last nights", "Help me sleep better"]
                case .deepSleep, .remSleep, .awake: return ["Help me sleep better", "What do tags show?", "Why was sleep poor?"]
                case .steps: return ["Plan a walk", "What’s my step goal?", "Weekly review"]
                case .workoutMinutes: return ["Plan my week", "Training too much?", "Weekly review"]
                default: return ["Why is recovery low?", "Plan my workout", "Weekly review"]
                }
            }()
            let head = "\(short == "RHR" ? "Resting HR" : info.name) \(s.valueText)\(unit) is \(dir)."
            return reply(head, sentences, pills: [pill(id)] + related.map { $0 == .sleepTotal ? sleepPill() : pill($0) }, chips: chips)
        }

        func planReply(_ q: String, kind requestedKind: String?, focus: String? = nil, fallbackMinutes: Int?) -> CoachReply {
            var kind = requestedKind
            var maxZone: Int? = nil
            if kind == nil {
                if q.contains("strength") || q.contains("bodyweight") || q.contains("dumbbell") { kind = "strength" }
                else if q.contains("run") { kind = "run" }
                else if q.contains("ride") || q.contains("bike") || q.contains("cycl") { kind = "ride" }
                else if q.contains("walk") { kind = "walk" }
                else if q.contains("zone 2") || q.contains("easy session") { kind = "cardio"; maxZone = 2 }
                else if q.contains("hard") || q.contains("interval") { kind = cap == .any ? "intervals" : nil }
            }
            if q.contains("easier") || q.contains("easy") { maxZone = min(maxZone ?? 2, 2) }
            let profile = CoachProfile.saved
            var gear = profile.equipment
            if q.contains("dumbbell") { gear = "Dumbbells" }
            if q.contains("no gear") || q.contains("bodyweight") { gear = nil }
            let parsed = Template.minutes(in: q)
            let defaultMinutes: Int = {
                switch cap {
                case .rest: return 20
                case .easy: return 30
                case .moderate: return 30
                case .any: return 40
                }
            }()
            var minutes = parsed ?? fallbackMinutes ?? defaultMinutes
            if q.contains("shorter") { minutes = max(5, minutes / 2) }
            if q.contains("longer") { minutes = minutes + 10 }
            var effectiveCap = cap
            if q.contains("easier") { effectiveCap = cap.capped(at: .easy) }
            var avoid: Set<String> = []
            if c.unwell { avoid.insert("unwell") }
            let indoor = q.contains("indoor") || q.contains("desk") || q.contains("home")
            var focusWord = focus
            if q.contains("hips") { focusWord = "hips" }
            if q.contains("desk") { focusWord = "desk" }
            if q.contains("post-run") || q.contains("after my run") { focusWord = "runners" }

            var plans = CoachLibrary.find(cap: effectiveCap, minutes: minutes, equipment: gear, kind: kind, focus: focusWord,
                                          maxZone: maxZone, avoid: avoid, indoorOnly: indoor, age: c.age, limit: 3)
            if plans.isEmpty {
                plans = CoachLibrary.find(cap: effectiveCap, minutes: minutes, equipment: gear, kind: kind, avoid: avoid, age: c.age, limit: 3)
            }
            if plans.isEmpty {
                plans = CoachLibrary.find(cap: .rest, minutes: min(minutes, 20), equipment: nil, kind: "recovery", age: c.age, limit: 1)
            }
            guard let plan = plans.first else {
                return reply("An easy walk is the best fit today.", [capReason],
                             chips: ["Help me sleep better", "Why is recovery low?", "Weekly review"])
            }
            var sentences = [capReason]
            if (q.contains("hard") || q.contains("interval")) && cap != .any {
                sentences = ["Not today: " + lowerFirst(capReason)]
            }
            sentences.append(CoachLibrary.safetyCue)
            let chips: [String] = {
                switch kind {
                case "breath": return ["Another round", "Why does it work?", "Wind-down routine"]
                case "winddown": return ["Breathing only", "Longer", "Help me sleep better"]
                case "mobility": return ["Hips focus", "Desk version", "Make it shorter"]
                case "recovery": return ["Mobility only", "Walk only", "Calm me down"]
                default: return ["Make it shorter", "Indoor version", "Why this plan?"]
                }
            }()
            let head = limitWords("\(plan.title), \(plan.minutes) min.", 14)
            return reply(head, sentences, pills: kind == "breath" || kind == "winddown" ? [] : [pill(.restingHR), sleepPill()],
                         chips: chips, plan: plan)
        }

        static func minutes(in q: String) -> Int? {
            // "20 min", "20-min", "20 minutes"
            guard let r = q.range(of: "\\d{1,3}\\s*-?\\s*min", options: .regularExpression) else { return nil }
            let digits = q[r].prefix { $0.isNumber }
            guard let v = Int(digits), v > 0, v <= 180 else { return nil }
            return v
        }

        func hardness() -> CoachReply {
            if c.gentle {
                return reply("No strain target in gentle mode.", [capReason, "Move when it feels good: walks and mobility count."],
                             chips: ["Plan an easy walk", "Help me sleep better", "Weekly review"])
            }
            var s: [String] = []
            if let r = c.recovery { s.append("Recovery is \(r.score) %, so \(cap.plainWord) effort fits.") } else { s.append(capReason) }
            if let st = c.strainNow { s.append("Strain is \(fmt1(st)) so far.") }
            if has("R6") { s.append("You’ve reached it: a cool-down or walk is enough.") }
            return reply("Aim for strain \(fmtRange(c.target)) today.", s,
                         pills: [pill(.restingHR), sleepPill()],
                         chips: ["Plan my workout", "Explain my strain", "What are my zones?"])
        }

        func zones() -> CoachReply {
            let z = CoachLibrary.zonesBPM(age: c.age)
            let maxHR = c.age.map { Int((208 - 0.7 * Double($0)).rounded()) } ?? 185
            let table = z.enumerated().map { "Z\($0.offset + 1) \($0.element.lowerBound)–\($0.element.upperBound)" }.joined(separator: " · ")
            return reply("Your zones, from a max heart rate of \(maxHR) bpm.",
                         [table + ".", c.age == nil ? "Add your date of birth in Apple Health for zones by age." : "Zone 2 is the easy, chatty pace."],
                         chips: ["Plan Zone 2", "Explain my strain", "How hard today?"])
        }

        func sleepWhy() -> CoachReply {
            guard let n = c.lastSleep else {
                return reply("No night synced yet.", [MissingState.waiting.text + ". Open Google Health so it can sync."],
                             chips: ["Help me sleep better", "What can you see?", "Weekly review"])
            }
            var s: [String] = []
            let eff = Int((n.efficiency * 100).rounded())
            s.append("\(fmtMin(n.asleepMinutes)) asleep out of \(fmtMin(n.inBedMinutes)) in bed (\(eff) %).")
            let awake = c.state(.awake)
            if awake.isConcern { s.append("Awake time \(awake.valueText) was above your normal \(awake.yourRangeText).") }
            if let tag = c.tagsYesterday.sorted().first { s.append("You tagged \(tag.lowercased()) yesterday.") }
            else if let sp = c.spread, sp > 45 { s.append("Your bedtime varies by ±\(Int(sp.rounded())) min.") }
            let score = c.sleepScore.map { "Sleep score \($0)" } ?? "Last night"
            let good = (c.sleepScore ?? 0) >= 80
            return reply(good ? "\(score): a solid night." : "\(score): \(n.asleepMinutes < 420 ? "under 7 h asleep" : "some room to improve").",
                         s, pills: [sleepPill(), pill(.awake), pill(.deepSleep)],
                         chips: ["Help me sleep better", "What do tags show?", "Wind-down routine"])
        }

        func sleepBetter() -> CoachReply {
            // Priority (decision 5): regularity → duration → tag-linked → debt.
            var head = "Keep the same bedtime, give or take 30 min."
            var s: [String] = []
            if let sp = c.spread, sp > 45 {
                head = "Bedtime varies by ±\(Int(sp.rounded())) min: keep it within 30."
                s.append("A regular bedtime matters more than a long lie-in.")
            } else if let a = c.asleep, a < 420 {
                head = "Aim for 7 h or more: you got \(fmtMin(a))."
                s.append("Get into bed 30 min earlier tonight.")
            } else if let sig = signal("S-c") ?? signal("S-d") {
                head = "Your tags point to one change."
                s.append(sig.text)
            } else if c.debt > 300 {
                head = "Sleep debt \(fmtMin(c.debt)): one earlier night helps."
                s.append("Go to bed 30–45 min earlier rather than sleeping in.")
            } else {
                s.append("Your sleep looks steady. A cool, dark room and a 10-min wind-down keep it that way.")
            }
            if let b = c.usualBedtime { s.append("Caffeine cut-off: about \(clock((b - 480 + 1440) % 1440)).") }
            let plan = CoachLibrary.find(cap: .rest, minutes: 10, equipment: nil, kind: "winddown", age: c.age, limit: 1).first
            return reply(head, s, pills: [sleepPill()], chips: ["Wind-down now", "Caffeine cut-off?", "Breathing to fall asleep"], plan: plan)
        }

        func caffeine() -> CoachReply {
            guard let b = c.usualBedtime else {
                return reply("Stop caffeine 8 h before bed.", ["Its effect on sleep often goes unnoticed."],
                             chips: ["Help me sleep better", "Wind-down routine", "What do tags show?"])
            }
            return reply("Last caffeine around \(clock((b - 480 + 1440) % 1440)).",
                         ["That’s 8 h before your usual bedtime of \(clock(b)).", "Caffeine can cut sleep without you noticing."],
                         chips: ["Help me sleep better", "Wind-down routine", "What do tags show?"])
        }

        func regularity() -> CoachReply {
            let sp = c.spread.map { "Your bedtime varies by ±\(Int($0.rounded())) min." } ?? "Coach needs 3 nights to measure this."
            return reply("A steady bedtime helps more than a long lie-in.",
                         [sp, "Regular sleep times are linked to better health than duration alone."],
                         chips: ["Help me sleep better", "Wind-down routine", "Weekly review"])
        }

        func debt() -> CoachReply {
            if c.debt < 30 {
                return reply("Hardly any sleep debt this week.", ["You’re within 30 min of 8 h a night over 7 nights."],
                             pills: [sleepPill()], chips: ["Help me sleep better", "Weekly review", "Plan my workout"])
            }
            return reply("Sleep debt \(fmtMin(c.debt)) over 7 nights.",
                         ["Pay it back with one or two nights 30–45 min earlier.", "Long lie-ins shift your body clock, so skip them."],
                         pills: [sleepPill()], chips: ["Is a nap OK?", "Wind-down routine", "Weekly review"])
        }

        func nap() -> CoachReply {
            reply("A short nap before 3 pm is fine.",
                  ["Keep it to about 20 min so it doesn’t push back your bedtime."],
                  pills: [sleepPill()], chips: ["Pay back sleep debt", "Help me sleep better", "Wind-down routine"])
        }

        func weekly() -> CoachReply {
            guard let w = c.health.weekly else {
                return reply("Not enough data for a weekly review yet.", ["It needs a few synced days."],
                             chips: ["Plan my workout", "What can you see?", "Help me sleep better"])
            }
            var head = "Your week"
            if let r = w.avgRecovery { head += ": recovery \(r) % on average" }
            head += "."
            var s: [String] = []
            var bits: [String] = ["\(Int(w.workoutMinutes.rounded())) workout min"]
            if let sl = w.avgSleep { bits.append("\(fmtMin(sl)) sleep a night") }
            if let st = w.avgSteps { bits.append("\(MetricID.steps.format(st)) steps a day") }
            s.append(bits.joined(separator: ", ") + ".")
            if let b = w.best { s.append(b.sentence) }
            if let wr = w.worst { s.append(wr.sentence) }
            return reply(limitWords(head, 14), s, pills: [pill(.workoutMinutes), sleepPill(), pill(.restingHR)],
                         chips: ["Plan my week", "What slipped this week?", "Help me sleep better"])
        }

        func planWeek() -> CoachReply {
            let days = CoachProfile.saved.daysPerWeek ?? 3
            let strength = days >= 3 ? 2 : 1
            let cardio = max(days - strength, 1)
            let have = Int((c.state(.workoutMinutes).latest?.value ?? 0).rounded())
            return reply("This week: \(strength) strength and \(cardio) Zone 2 sessions.",
                         ["Space hard days apart, and never two hard days in a row.",
                          "About 150 min in total meets the weekly guideline" + (have > 0 ? "; you did \(have) last 7 days." : "."),
                          "Coach adjusts each day to your recovery."],
                         pills: [pill(.workoutMinutes)], chips: ["Plan my workout", "Fewer days", "Add strength"])
        }

        func tooMuch() -> CoachReply {
            var s: [String] = []
            if let l2 = signal("L2") { s.append(l2.text) }
            if let r5 = signal("R5") { s.append(r5.text) }
            if s.isEmpty {
                return reply("Your load looks steady.",
                             ["No big jump vs your usual week and no run of hard days."],
                             pills: [pill(.workoutMinutes), pill(.restingHR)], chips: ["Plan my workout", "Weekly review", "Plan my week"])
            }
            return reply("You’ve stepped up: ease in this week.", s + ["An easier week lets your body catch up."],
                         pills: [pill(.workoutMinutes), pill(.restingHR)], chips: ["Plan an easy session", "Weekly review", "Plan my week"])
        }

        func unwell() -> CoachReply {
            reply("Feeling unwell: use the neck check.",
                  ["Only above the neck, like a runny nose: an easy walk is fine.",
                   "Fever, chest symptoms or aches: rest fully.",
                   "Ease back in once you’ve felt normal for a day or two."],
                  pills: [pill(.restingHR), pill(.breathing)],
                  chips: ["Plan a rest day", "When to train again?", "Help me sleep better"])
        }

        func stressReply() -> CoachReply {
            let tense = c.health.stressHours.filter { ($0.level ?? 0) >= 2 }.count
            let head = tense > 0 ? "Stress ran high for \(tense) hours today." : "Stress has been calm today."
            return reply(head, ["Stress here means heart rate above rest while you were still.",
                                "Slow breathing with long exhales often brings it down."],
                         chips: ["Calm me down", "Why does breathing help?", "Wind-down routine"])
        }

        func breathingWhy() -> CoachReply {
            reply("Long exhales slow your heart rate.",
                  ["Breathing slower than 10 a minute calms your nervous system.",
                   "Five minutes of cyclic sighing lifted mood in a Stanford study."],
                  chips: ["Calm me down", "Another round", "Wind-down routine"])
        }

        func strengthWhy() -> CoachReply {
            reply("Strength twice a week keeps muscles and bones strong.",
                  ["It’s part of the WHO activity guideline, alongside 150 min of moderate cardio.", "20 min with no gear is enough to start."],
                  chips: ["Quick strength, no gear", "Plan my week", "Plan my workout"])
        }

        func stepsReply(_ q: String) -> CoachReply {
            let goal = c.stepGoal
            let y = c.state(.steps).latest.map { MetricID.steps.format($0.value) }
            var s = ["A good range for you is \(goal.lowerBound.formatted())–\(goal.upperBound.formatted()) a day."]
            if let today = c.health.stepsToday { s.append("Today so far: \(MetricID.steps.format(today)).") }
            if q.contains("walking count") { s = ["Walks count as steps. Brisk walks also count toward the 150 weekly minutes."] + s }
            return reply(y.map { "Yesterday: \($0) steps." } ?? "Steps add up best with short walks.", s,
                         pills: [pill(.steps)], chips: ["Plan a walk", "Weekly review", "Plan my workout"])
        }

        func tagsReply() -> CoachReply {
            let d = c.journal.discoveries
            if d.isEmpty {
                return reply("No tag patterns yet.", [c.journal.progressText ?? "Keep tagging your days with “+” on Today."],
                             chips: ["Help me sleep better", "Weekly review", "Plan my workout"])
            }
            return reply("What your tags show.", Array(d.prefix(3)),
                         chips: ["Help me sleep better", "Weekly review", "Why was sleep poor?"])
        }

        func whatISee() -> CoachReply {
            reply("Coach reads your Apple Health data on this iPhone.",
                  ["Heart rate, resting HR, sleep stages, breathing, SpO2, steps, active energy, workouts and your journal tags.",
                   "HRV, skin temperature and VO2 max are not sent by Google Health.",
                   "Nothing leaves this iPhone."],
                  chips: ["Plan my workout", "Weekly review", "Help me sleep better"])
        }

        private func lowerFirst(_ s: String) -> String { s.prefix(1).lowercased() + s.dropFirst() }
        private func lowerFirstSentence(_ s: String) -> String {
            let first = s.components(separatedBy: ". ").first ?? s
            return first.hasSuffix(".") ? first : first + "."
        }
    }
}
