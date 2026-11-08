import Foundation

// v1.3 · scripted self-test for the Coach bug fixes B1–B5 (GOAL_v1.3, DESIGN_SPEC_v1.3 §5). Owner: agent C.
// DEBUG only. Run with the `-runChecks` launch argument (ContentView prints every line as "CHECK …").
// It temporarily overrides recovery / workout minutes / one journal tag on the live stores and restores
// them before returning. The journal tag check only runs in demo mode (demo journals are never written to disk).

#if DEBUG
@MainActor
enum CoachRulesChecks {

    /// Runs every check and returns the failures (empty = all passed). `log` gets one line per check.
    static func run(health: HealthStore, journal: JournalStore, log: ((String) -> Void)? = nil) -> [String] {
        var failures: [String] = []
        func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
            let line = (ok ? "PASS " : "FAIL ") + name + (ok ? "" : " — " + detail())
            log?(line)
            if !ok { failures.append(line) }
        }

        // Keep the real values to restore them at the end.
        let savedRecovery = health.recovery
        let savedWorkouts = health.states[.workoutMinutes]
        defer {
            health.recovery = savedRecovery
            health.states[.workoutMinutes] = savedWorkouts
        }
        let contributors = savedRecovery?.contributors ?? []
        health.recovery = RecoveryResult(score: 63, contributors: contributors)

        // ---- B3 · recovery chip follows the tier ----
        check("B3 chip red 20", CoachRules.recoveryChip(20) == "Why is recovery low?", CoachRules.recoveryChip(20))
        check("B3 chip yellow 63", CoachRules.recoveryChip(63) == "What affects my recovery?", CoachRules.recoveryChip(63))
        check("B3 chip green 80", CoachRules.recoveryChip(80) == "What helped recovery?", CoachRules.recoveryChip(80))
        let rewritten = CoachEngine.fixRecoveryChips(["Why is recovery low?", "How did I sleep?", "Why is my recovery high?"], score: 63)
        check("B3 model chips rewritten at 63", rewritten == ["What affects my recovery?", "How did I sleep?"], "\(rewritten)")
        let starters = CoachStarterSource.make(health).map(\.question)
        check("B3 Coach tab starter at 63", starters.first == "What affects my recovery?", "\(starters)")
        let rulesStarters = CoachRules.starters(health: health)
        check("B3 CoachRules.starters at 63 not 'low'", !rulesStarters.contains("Why is recovery low?"), "\(rulesStarters)")
        let sleepReply = CoachRules.templateReply(for: "How was last night?", metric: .sleepTotal, health: health, journal: journal)
        check("B3 sleep reply chips at 63 not 'low'",
              !sleepReply.chips.contains { $0.localizedCaseInsensitiveContains("recovery low") }, "\(sleepReply.chips)")

        // ---- B2 · a topic named in the question wins over the chat's metric ----
        let f1 = CoachRules.focus(for: "Why is recovery low?", context: .spo2)
        check("B2 focus 'Why is recovery low?' in SpO2 sheet = recovery", f1 == .recovery, "\(f1)")
        let f2 = CoachRules.focus(for: "Why is recovery low?", context: .sleepTotal)
        check("B2 focus 'Why is recovery low?' in sleep sheet = recovery", f2 == .recovery, "\(f2)")
        check("B2 engine drops sheet metric for recovery question",
              CoachEngine.focusedMetric(for: "Why is recovery low?", context: .sleepTotal) == nil)
        check("B2 generic question keeps the sheet metric",
              CoachEngine.focusedMetric(for: "What does this mean?", context: .spo2) == .spo2)
        check("B2 named metric wins", CoachEngine.focusedMetric(for: "Is my RHR okay?", context: .sleepTotal) == .restingHR)
        let about = CoachEngine.focusedMetric(for: "Why is recovery low?", context: .sleepTotal)
        let recReply = CoachRules.templateReply(for: "Why is recovery low?", metric: about, health: health, journal: journal)
        let recText = recReply.headline + " " + recReply.body
        check("B2 recovery question gets a recovery reply (not total sleep)",
              !recText.hasPrefix("Total sleep") && recText.localizedCaseInsensitiveContains("recover"), recText)
        check("B2 model prompt names the topic",
              CoachEngine.prompt("Why is recovery low?", metric: nil, topic: CoachEngine.topicName(f2)).contains("about recovery"))

        // ---- B5 · journal tags only for metrics they affect ----
        let spo2Tags = CoachRules.relevantTags(for: .spo2)
        check("B5 SpO2 tags exclude caffeine", !spo2Tags.contains("Caffeine after 2 pm"), "\(spo2Tags.sorted())")
        check("B5 sleep tags include caffeine", CoachRules.relevantTags(for: .sleepTotal).contains("Caffeine after 2 pm"))
        check("B5 SpO2 allowed tags (engine) exclude caffeine",
              CoachEngine.allowedTags(.metric(.spo2), metric: .spo2)?.contains("Caffeine after 2 pm") == false)
        if health.isDemo {
            let yday = Calendar.current.date(byAdding: .day, value: -1, to: Demo.now) ?? Demo.now
            let had = journal.isOn("Caffeine after 2 pm", date: yday)
            journal.toggle(tag: "Caffeine after 2 pm", on: true, date: yday)
            defer { journal.toggle(tag: "Caffeine after 2 pm", on: had, date: yday) }

            let ctx = CoachToolContext(health: health, journal: journal)
            ctx.beginTurn()
            ctx.setFocus(metric: .spo2, allowedTags: CoachEngine.allowedTags(.metric(.spo2), metric: .spo2))
            let out = ctx.getJournal(days: 3)
            check("B5 getJournal in SpO2 turn hides caffeine", !out.localizedCaseInsensitiveContains("caffeine"), out)
            ctx.beginTurn()
            ctx.setFocus(metric: .sleepTotal, allowedTags: CoachEngine.allowedTags(.metric(.sleepTotal), metric: .sleepTotal))
            let outSleep = ctx.getJournal(days: 3)
            check("B5 getJournal in sleep turn keeps caffeine", outSleep.localizedCaseInsensitiveContains("caffeine"), outSleep)

            let spo2Reply = CoachRules.templateReply(for: "Why is my blood oxygen low?", metric: .spo2, health: health, journal: journal)
            check("B5 SpO2 template reply never cites caffeine",
                  !(spo2Reply.headline + " " + spo2Reply.body).localizedCaseInsensitiveContains("caffeine"),
                  spo2Reply.headline + " " + spo2Reply.body)
        } else {
            log?("SKIP B5 journal-tag checks (real data: the journal is not modified)")
        }

        // ---- B1 · load-jump note carries an easy cap, and todayCap reads the same cap ----
        let today = Calendar.current.startOfDay(for: Demo.now)
        let series: [DayValue] = (0..<35).reversed().compactMap { ago in
            guard let d = Calendar.current.date(byAdding: .day, value: -ago, to: today) else { return nil }
            return DayValue(date: d, value: ago == 0 ? 120 : 60)   // 7-day total 120 vs ~60 usual → L2
        }
        health.states[.workoutMinutes] = MetricState.make(.workoutMinutes, series: series)
        let both = journal.entries(for: Demo.now).union(journal.entries(for: Calendar.current.date(byAdding: .day, value: -1, to: Demo.now) ?? Demo.now))
        let gentle = both.contains { ["travel", "feeling unwell"].contains($0.lowercased()) }
        if gentle {
            log?("SKIP B1 (gentle mode: travel / unwell tagged, load rules are off)")
        } else {
            let signals = CoachRules.signals(health, journal: journal)
            let l2 = signals.first { $0.id == "L2" }
            check("B1 L2 fires on a load jump", l2 != nil, "fired: \(signals.map(\.id))")
            check("B1 L2 cap is .easy", l2?.cap == .easy, "cap \(String(describing: l2?.cap))")
            let rulesCap = signals.compactMap(\.cap).min { rank($0) < rank($1) } ?? .any
            if CoachPrefs.isEnabled {
                let cap = CoachRules.todayCap(health)
                check("B1 todayCap matches the rules cap", cap == rulesCap, "todayCap \(cap) vs rules \(rulesCap)")
                check("B1 todayCap is easy or stricter on a load jump", rank(cap) <= rank(.easy), "todayCap \(cap)")
            }
            // Any fired rule text that says "ease"/"easy" must come with a cap.
            let loose = signals.filter { s in
                let t = s.text.lowercased()
                return (t.contains("ease in") || t.contains("easy")) && rulesCap == .any
            }
            check("B1 no 'ease/easy' advice under cap .any", loose.isEmpty, "\(loose.map(\.id))")
        }

        // ---- Coach note chips send their question ----
        let nav = AppNav()
        nav.openCoach(about: nil, asking: "Plan an easy session")
        if CoachPrefs.isEnabled {
            check("Nav chip → Coach tab", nav.tab == .coach)
            check("Nav chip → prompt queued", nav.coachPrompt == "Plan an easy session")
            check("Nav takeCoachPrompt clears", nav.takeCoachPrompt() == "Plan an easy session" && nav.coachPrompt == nil)
            let nav2 = AppNav()
            nav2.openCoach(about: .workoutMinutes, asking: "Training too much?")
            check("Nav chip with metric → sheet + prompt",
                  nav2.showCoachSheet && nav2.coachMetric == .workoutMinutes && nav2.coachPrompt == "Training too much?")
        } else {
            check("Nav chip with Coach off does nothing", nav.tab == .today && nav.coachPrompt == nil)
        }

        return failures
    }

    private static func rank(_ c: IntensityCap) -> Int {
        switch c {
        case .rest: 0
        case .easy: 1
        case .moderate: 2
        case .any: 3
        }
    }
}
#endif
