import Foundation

// v1.1 Coach · deterministic guardrails before/after the model (research/v11-04 G1, G3, G4, G5, G6). Owner: agent M.
// Pure Swift, no network, no model. Every fixed reply is written here, never generated.
//
// preCheck  → runs on the user's text BEFORE the model. Returns a fixed, localised CoachReply (isTemplate = true)
//             for emergency / crisis / minor / eating / medication / threshold / diagnosis / pain / weight-target /
//             jailbreak / Health-write messages, nil when the text may go to the model.
// postCheck → runs on the model's reply AFTER generation. False when it uses a banned word, a calorie / weight target,
//             injury talk, or cites a number that is not in the tool results (`allowedNumbers`).

enum CoachSafety {

    // MARK: - Public API

    enum Category: String, CaseIterable {
        case crisis, emergency, minor, eatingDisorder, medication, threshold, diagnosis, pain, weightTarget,
             jailbreak, healthWrite
        /// Not blocked: the model may answer with general wellness info only (see `modelGuidance(for:)`).
        case condition

        /// True when the chat must stop coaching entirely after this reply (no model turn until a new chat).
        var endsCoaching: Bool { self == .crisis || self == .emergency || self == .minor }
    }

    /// Fixed, localised reply for emergency / crisis / medical messages; nil = safe to send to the model.
    static func preCheck(_ text: String) -> CoachReply? { preCheck(text, region: currentRegion) }

    static func preCheck(_ text: String, region: String?) -> CoachReply? {
        let tokens = tokenize(text)
        if let follow = followUp(tokens, region: region) { return follow }
        guard let cat = category(tokens), cat != .condition else { return nil }
        return reply(for: cat, region: region)
    }

    /// Safety category of a user message, nil when nothing matched. `.condition` still goes to the model.
    static func category(of text: String) -> Category? { category(tokenize(text)) }

    /// Extra instruction for the model's prompt when a message is allowed through but needs care.
    static func modelGuidance(for category: Category?) -> String? {
        guard category == .condition else { return nil }
        return "The user mentioned pregnancy or a health condition. Give general wellness information only, make no plan tied to the condition, and suggest checking with their clinician."
    }

    /// False if the reply cites numbers not in tool results or uses banned words.
    static func postCheck(_ reply: CoachReply, allowedNumbers: Set<String>) -> Bool {
        violations(reply, allowedNumbers: allowedNumbers).isEmpty
    }

    /// Human-readable reasons a reply fails `postCheck` (empty = passes). Useful for logs and the debug menu.
    static func violations(_ reply: CoachReply, allowedNumbers: Set<String>) -> [String] {
        var out: [String] = []
        var wordText = [reply.headline, reply.body].joined(separator: "\n")
        wordText += "\n" + reply.pills.map(\.text).joined(separator: "\n")
        wordText += "\n" + reply.chips.joined(separator: "\n")
        if let plan = reply.plan {
            wordText += "\n" + plan.title + "\n" + plan.steps.map { "\($0.name) \($0.cue) \($0.reps ?? "")" }.joined(separator: "\n")
        }
        let folded = fold(wordText)
        for (name, re) in bannedPatterns where re.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)) != nil {
            out.append("banned: \(name)")
        }

        // Numbers: headline, body and pills must only cite numbers from the tool results (or the attached library plan).
        var allowed = Set(allowedNumbers.flatMap { numbers(in: $0, exemptTerms: false) }.flatMap(variants))
        if let plan = reply.plan {
            allowed.insert(canonical(String(plan.minutes)))
            for s in plan.steps {
                if let sec = s.seconds { allowed.formUnion([canonical(String(sec)), canonical(String(sec / 60))]) }
                if let r = s.reps { allowed.formUnion(numbers(in: r, exemptTerms: false)) }
            }
        }
        let cited = ([reply.headline, reply.body] + reply.pills.map(\.text)).flatMap { numbers(in: $0, exemptTerms: true) }
        for n in cited where !allowed.contains(n) { out.append("number not in tool results: \(n)") }
        return out
    }

    /// Footer on every coach screen (DESIGN_SPEC_v1.1 §5).
    static var footer: String { String(localized: "AI coach on this iPhone · can be wrong · wellness, not medical advice.", comment: "Coach footer") }

    /// Intended purpose, identical everywhere (store, onboarding, coach intro, policy).
    static var intendedPurpose: String {
        String(localized: "MRH1 Coach gives general wellness and fitness suggestions based on your own Apple Health data. It is not a medical device and does not diagnose, treat or prevent any condition. Check with a doctor before making health decisions.", comment: "Coach intended purpose")
    }

    // MARK: - Region numbers

    struct PhoneNumber: Equatable {
        /// What the user reads, e.g. "112", "15 or 112", "116 123".
        let display: String
        /// Digits to dial, e.g. "15". Use `URL(string: "tel://\(dial)")`.
        let dial: String
        var url: URL? { URL(string: "tel://\(dial)") }
    }

    struct Helpline: Equatable {
        let name: String
        let phone: PhoneNumber?
        /// SMS short code when the line offers text support.
        let text: String?
    }

    static var currentRegion: String? { Locale.current.region?.identifier }

    /// Local emergency number. Defaults to 112, which also works on most mobile networks worldwide.
    static func emergencyNumber(region: String? = currentRegion) -> PhoneNumber {
        let r = (region ?? "").uppercased()
        func n(_ d: String) -> PhoneNumber { PhoneNumber(display: d, dial: d) }
        switch r {
        case "US", "CA", "MX", "PR", "GU", "VI", "AS", "MP", "PA", "CR", "SV", "GT", "HN", "NI", "AR", "PE", "PY", "UY", "VE", "DO", "PH":
            return n("911")
        case "GB", "IE", "HK", "MO", "MY", "BW":
            return PhoneNumber(display: r == "GB" || r == "IE" ? String(localized: "999 or 112", comment: "UK/IE emergency") : "999", dial: "999")
        case "FR": return PhoneNumber(display: String(localized: "15 or 112", comment: "FR emergency"), dial: "15")
        case "CH": return PhoneNumber(display: String(localized: "144 or 112", comment: "CH emergency"), dial: "144")
        case "AU": return n("000")
        case "NZ": return n("111")
        case "JP", "KR", "TW": return n("119")
        case "CN": return n("120")
        case "BR": return n("192")
        case "SG": return n("995")
        case "IL": return n("101")
        case "ZA": return PhoneNumber(display: String(localized: "10177 or 112", comment: "ZA emergency"), dial: "10177")
        case "TH": return n("1669")
        default: return n("112")
        }
    }

    /// Crisis helpline, nil phone = point to findahelpline.com.
    static func crisisLine(region: String? = currentRegion) -> Helpline {
        func h(_ name: String, _ d: String, text: String? = nil) -> Helpline {
            Helpline(name: name, phone: PhoneNumber(display: d, dial: d.filter(\.isNumber)), text: text)
        }
        switch (region ?? "").uppercased() {
        case "US": return h("988 Lifeline", "988", text: "988")
        case "CA": return h("9-8-8", "988", text: "988")
        case "GB": return h("Samaritans", "116 123", text: "85258")
        case "IE": return h("Samaritans", "116 123", text: "50808")
        case "FR": return h("3114", "3114")
        case "DE": return h("TelefonSeelsorge", "0800 111 0 111")
        case "AT": return h("Telefonseelsorge", "142")
        case "ES": return h("024", "024")
        case "NL": return h("113", "0800 0113")
        case "AU": return h("Lifeline", "13 11 14")
        case "NZ": return h("1737", "1737", text: "1737")
        default: return Helpline(name: "findahelpline.com", phone: nil, text: nil)
        }
    }

    /// Eating-disorder support line, nil phone = point to findahelpline.com.
    static func eatingLine(region: String? = currentRegion) -> Helpline {
        switch (region ?? "").uppercased() {
        case "GB": return Helpline(name: "Beat", phone: PhoneNumber(display: "0808 801 0677", dial: "08088010677"), text: nil)
        case "AU": return Helpline(name: "Butterfly", phone: PhoneNumber(display: "1800 33 4673", dial: "1800334673"), text: nil)
        default: return Helpline(name: "findahelpline.com", phone: nil, text: nil)
        }
    }

    // MARK: - Fixed replies (headline ≤ 14 words, ≤ 2 sentences, exactly 3 chips, no exclamation marks)

    static func reply(for category: Category, region: String? = currentRegion) -> CoachReply? {
        let e = emergencyNumber(region: region).display
        switch category {
        case .emergency:
            return tpl(String(localized: "This could be urgent. Call \(e) now.", comment: "Emergency headline"),
                       String(localized: "Stop what you are doing and call \(e), or ask someone near you to call. Coach can't help with this.", comment: "Emergency body"),
                       emergencyChips)
        case .crisis:
            let line = crisisLine(region: region)
            let body: String
            if let p = line.phone {
                body = String(localized: "You can call \(p.display) any time to talk to someone now. If you might act on these thoughts, call \(e).", comment: "Crisis body")
            } else {
                body = String(localized: "Find a free, private helpline at findahelpline.com, or talk to someone you trust. If you might act on these thoughts, call \(e).", comment: "Crisis body, no local line")
            }
            return tpl(String(localized: "You don't have to go through this alone", comment: "Crisis headline"), body, crisisChips)
        case .minor:
            return tpl(String(localized: "Coach is for people 18 and over", comment: "Minor headline"),
                       String(localized: "The rest of the app still works for you, with all your scores and charts. For a training plan, ask a parent, coach or PE teacher.", comment: "Minor body"),
                       minorChips)
        case .eatingDisorder:
            let line = eatingLine(region: region)
            let body: String
            if let p = line.phone {
                body = String(localized: "Coach doesn't make plans to eat less or to make up for food with exercise. If food or your body feels hard right now, \(line.name) can help on \(p.display).", comment: "Eating body")
            } else {
                body = String(localized: "Coach doesn't make plans to eat less or to make up for food with exercise. If food or your body feels hard right now, you can find free support at findahelpline.com.", comment: "Eating body, no local line")
            }
            return tpl(String(localized: "That sounds hard, and you deserve support", comment: "Eating headline"), body,
                       [String(localized: "Who offers support?"), String(localized: "How was my sleep?"), String(localized: "Ideas to unwind tonight?")])
        case .medication:
            return tpl(String(localized: "A doctor or pharmacist is the right person for this", comment: "Medication headline"),
                       String(localized: "Coach can't advise on medicines, supplements, alcohol or how much to take. Please don't start, stop or change anything without asking them.", comment: "Medication body"),
                       [String(localized: "How was my sleep?"), String(localized: "What's my recovery today?"), String(localized: "Ideas for better sleep?")])
        case .diagnosis:
            return tpl(String(localized: "I can't tell you what a symptom means", comment: "Diagnosis headline"),
                       String(localized: "I can show how your numbers compare with your own normal. For symptoms or worries, talk to a doctor.", comment: "Diagnosis body"),
                       baselineChips)
        case .threshold:
            return tpl(String(localized: "Coach compares you with your own normal", comment: "Threshold headline"),
                       String(localized: "It doesn't use medical cut-offs. If you feel unwell or a number stays far from your usual range, a check with a healthcare professional may be helpful.", comment: "Threshold body"),
                       baselineChips)
        case .pain:
            return tpl(String(localized: "Rest it today and keep any movement pain-free", comment: "Pain headline"),
                       String(localized: "Skip anything that hurts and choose easy, comfortable movement. If it doesn't settle in a few days, see a doctor or physio.", comment: "Pain body"),
                       [String(localized: "What's my recovery today?"), String(localized: "How was my sleep?"), String(localized: "Rest day ideas?")])
        case .weightTarget:
            return tpl(String(localized: "Coach doesn't set calorie or weight targets", comment: "Weight headline"),
                       String(localized: "A doctor or registered dietitian can help with food and weight. I can help with sleep, steps and recovery.", comment: "Weight body"),
                       [String(localized: "How many steps today?"), String(localized: "How was my sleep?"), String(localized: "Plan an easy walk?")])
        case .jailbreak:
            return tpl(String(localized: "I stay a wellness coach", comment: "Jailbreak headline"),
                       String(localized: "I can't act as a doctor or change my rules. I can explain your numbers against your own normal.", comment: "Jailbreak body"),
                       [String(localized: "What can you do?"), String(localized: "Compare with my normal?"), String(localized: "How was my sleep?")])
        case .healthWrite:
            return tpl(String(localized: "Coach only reads your Apple Health data", comment: "Health write headline"),
                       String(localized: "It can't add, change or delete anything in Health. To edit a value, use the Health app.", comment: "Health write body"),
                       [String(localized: "What does Coach see?"), String(localized: "What's my resting HR?"), String(localized: "How was my sleep?")])
        case .condition:
            return nil
        }
    }

    // MARK: - Templated follow-up chips (never reach the model)

    private static var emergencyChips: [String] { [String(localized: "Who should I call?"), String(localized: "What do I say?"), String(localized: "What if it eases?")] }
    private static var crisisChips: [String] { [String(localized: "Who can I call?"), String(localized: "Can I text someone?"), String(localized: "What helps right now?")] }
    private static var minorChips: [String] { [String(localized: "Why is Coach 18+?"), String(localized: "What does Coach see?"), String(localized: "Do other tabs work?")] }
    private static var baselineChips: [String] { [String(localized: "Compare with my normal?"), String(localized: "How was my sleep?"), String(localized: "What's my resting HR?")] }

    private static func followUp(_ tokens: [String], region: String?) -> CoachReply? {
        let key = tokens.filter { $0 != "." }
        let e = emergencyNumber(region: region).display
        let line = crisisLine(region: region)
        let lineText = line.phone?.display ?? "findahelpline.com"
        let items: [(String, () -> CoachReply)] = [
            (String(localized: "Who should I call?"), {
                tpl(String(localized: "Call \(e), your local emergency number", comment: "Follow-up"),
                    String(localized: "If you can't call, ask someone near you to call for you. Stay where you are and unlock your door if you can.", comment: "Follow-up"),
                    emergencyChips) }),
            (String(localized: "What do I say?"), {
                tpl(String(localized: "Say what you feel and where you are", comment: "Follow-up"),
                    String(localized: "Tell them your symptoms, when they started and your address. Keep the line open and follow their instructions.", comment: "Follow-up"),
                    emergencyChips) }),
            (String(localized: "What if it eases?"), {
                tpl(String(localized: "Even if it eases, get checked now", comment: "Follow-up"),
                    String(localized: "Symptoms like these can come and go. Call \(e) or see a doctor today, and skip exercise until then.", comment: "Follow-up"),
                    emergencyChips) }),
            (String(localized: "Who can I call?"), {
                tpl(line.phone == nil ? String(localized: "Find a helpline near you at findahelpline.com", comment: "Follow-up")
                                      : String(localized: "Call \(lineText) to talk to someone now", comment: "Follow-up"),
                    String(localized: "It is free and private. A friend, a family member or your doctor can help too.", comment: "Follow-up"),
                    crisisChips) }),
            (String(localized: "Can I text someone?"), {
                if let t = line.text {
                    return tpl(String(localized: "Text \(t) to reach someone now", comment: "Follow-up"),
                               String(localized: "Someone will text back, any time of day. You can also text a friend and tell them you need support.", comment: "Follow-up"),
                               crisisChips)
                }
                return tpl(String(localized: "Many helplines offer chat or text", comment: "Follow-up"),
                           String(localized: "Visit findahelpline.com to find chat support near you. Texting a friend you trust helps too.", comment: "Follow-up"),
                           crisisChips) }),
            (String(localized: "What helps right now?"), {
                tpl(String(localized: "Reach out to one person now", comment: "Follow-up"),
                    String(localized: "Contact \(lineText) or someone you trust and tell them how you feel. If you might act on these thoughts, call \(e).", comment: "Follow-up"),
                    crisisChips) }),
            (String(localized: "Who offers support?"), {
                let ed = eatingLine(region: region)
                return tpl(String(localized: "Free, private support is available", comment: "Follow-up"),
                           ed.phone.map { String(localized: "Call \(ed.name) on \($0.display), or talk to your doctor or someone you trust.", comment: "Follow-up") }
                               ?? String(localized: "You can find support near you at findahelpline.com. Your doctor can help too.", comment: "Follow-up"),
                           [String(localized: "Who offers support?"), String(localized: "How was my sleep?"), String(localized: "Ideas to unwind tonight?")]) }),
            (String(localized: "Why is Coach 18+?"), {
                tpl(String(localized: "Health chat is built and checked for adults", comment: "Follow-up"),
                    String(localized: "Training advice for teens needs an adult who knows you. Your scores and charts still work as before.", comment: "Follow-up"),
                    minorChips) }),
            (String(localized: "What does Coach see?"), {
                tpl(String(localized: "Coach reads your Apple Health data on this iPhone", comment: "Follow-up"),
                    String(localized: "It sees heart rate, resting HR, sleep, breathing rate, SpO2, steps, active energy, workouts and your scores. Nothing leaves this iPhone.", comment: "Follow-up"),
                    [String(localized: "What can you do?"), String(localized: "Compare with my normal?"), String(localized: "How was my sleep?")]) }),
            (String(localized: "Do other tabs work?"), {
                tpl(String(localized: "Yes, Today, Live, Body and Trends work as before", comment: "Follow-up"),
                    String(localized: "Your scores and charts stay available. Only the Coach chat is for adults.", comment: "Follow-up"),
                    minorChips) }),
        ]
        for (chip, make) in items where tokenize(chip).filter({ $0 != "." }) == key { return make() }
        return nil
    }

    private static func tpl(_ headline: String, _ body: String, _ chips: [String]) -> CoachReply {
        CoachReply(headline: headline, body: body, pills: [], chips: chips, plan: nil, isTemplate: true)
    }

    // MARK: - Classifier (keyword rules, order = priority)

    private struct Rule {
        var any: [String] = []                       // phrases; tokens end in * for prefix, "." = sentence end
        var near: (a: [String], b: [String], window: Int)? = nil
        var unless: [String] = []                    // any of these anywhere cancels the rule
        var custom: (([String]) -> Bool)? = nil
    }

    private static func category(_ t: [String]) -> Category? {
        for (cat, rules) in rules where rules.contains(where: { matches($0, t) }) { return cat }
        return nil
    }

    private static let bodyParts = ["knee*", "back", "ankle*", "shoulder*", "hip", "hips", "foot", "feet", "wrist*", "neck", "shin*",
                                    "hamstring*", "calf", "calves", "achilles", "elbow*", "groin", "quad*", "heel*", "toe*", "leg", "legs", "arm", "chest"]
    private static let painWords = ["hurt*", "pain*", "ache*", "aching", "injur*", "sprain*", "swollen", "throb*", "sharp", "twinge*"]
    private static let medWords = ["medication*", "medicine*", "meds", "pill", "pills", "prescription*", "prescribed", "dosage*", "dose", "doses", "dosing",
                                   "mg", "milligram*", "beta blocker*", "betablocker*", "metoprolol", "bisoprolol", "propranolol", "atenolol", "statin*",
                                   "insulin", "metformin", "ozempic", "semaglutide", "wegovy", "mounjaro", "tirzepatide", "ssri*", "sertraline",
                                   "fluoxetine", "prozac", "zoloft", "antidepressant*", "xanax", "valium", "benzo", "benzos", "benzodiazepine*",
                                   "ambien", "zolpidem", "sleeping pill*", "sleeping tablet*", "melatonin", "ibuprofen", "advil", "paracetamol",
                                   "tylenol", "acetaminophen", "aspirin", "painkiller*", "opioid*", "steroid*", "testosterone", "trt",
                                   "blood thinner*", "antibiotic*", "inhaler*", "medicament*", "medikament*", "medicamento*", "pastilla*", "tabletten"]
    private static let metricWords = ["spo2", "oxygen", "o2", "saturation", "sats", "heart rate", "hr", "bpm", "rhr", "resting",
                                      "pulse", "breathing", "respiratory", "blood pressure", "bp", "heart"]
    private static let diseaseHard = ["apnea*", "apnoea*", "afib", "a fib", "atrial fibrillation", "arrhythmia*", "arrythmia*", "hypoxia", "hypoxic",
                                      "tachycardia", "bradycardia", "heart disease", "heart failure", "heart problem*", "cardiomyopathy", "myocarditis"]
    private static let diseaseSoft = ["covid*", "flu", "infection", "virus", "diabet*", "cancer", "condition", "disease", "disorder", "syndrome", "asthma",
                                      "anemia", "anaemia", "anemic", "thyroid", "hypertension", "insomnia", "illness",
                                      "sick", "long covid", "heart attack", "stroke", "pneumonia", "bronchitis"]
    private static let numberUnits: Set<String> = ["day", "days", "week", "weeks", "month", "months", "km", "k", "kms", "mile", "miles", "mi",
                                                   "minute", "minutes", "min", "mins", "hour", "hours", "h", "hr", "hrs", "kg", "kgs", "kilo", "kilos",
                                                   "lb", "lbs", "pound", "pounds", "stone", "st", "bpm", "percent", "steps", "nights", "night",
                                                   "reps", "sets", "times", "laps", "foot", "feet", "ft", "cm", "inches", "in", "seconds", "sec",
                                                   "pm", "am", "kcal", "calories", "miles", "x", "th", "of", "out"]

    private static let rules: [(Category, [Rule])] = [
        (.crisis, [
            Rule(any: ["kill myself", "killing myself", "suicid*", "end my life", "ending my life", "end it all", "want to die", "wanna die",
                       "wish i was dead", "wish i were dead", "dont want to live", "dont want to be alive", "dont want to be here anymore",
                       "no reason to live", "nothing to live for", "see the point anymore", "see the point .", "point in living",
                       "point of living", "point of anything", "point in anything", "point of life", "self harm*", "selfharm*",
                       "want to hurt myself", "going to hurt myself", "thinking of hurting myself", "thoughts of hurting myself", "harm myself",
                       "harming myself", "want to cut myself", "cutting myself", "better off dead",
                       "better off without me", "take my own life", "taking my own life", "feel hopeless", "feeling hopeless", "cant go on like this", "cant go on anymore", "cant go on .",
                       "me suicider", "me tuer", "envie de mourir", "en finir", "umbringen", "selbstmord", "nicht mehr leben",
                       "matarme", "quiero morir", "quitarme la vida"]),
        ]),
        (.emergency, [
            Rule(near: (["chest", "poitrine", "brust", "pecho"],
                        ["pain*", "hurt*", "tight*", "pressure", "crush*", "squeez*", "heavy", "heaviness", "ache*", "aching", "burning",
                         "douleur", "mal", "schmerz*", "dolor"], 3),
                 unless: ["sore*", "doms", "workout", "day", "bench", "press*", "pec", "pecs", "stretch*", "fly", "flys", "flies",
                          "pushup*", "push up*", "dip", "dips", "muscle*", "gym"]),
            // Chest symptom plus a classic companion overrides the gym-context exclusion.
            Rule(custom: { t in
                has(t, ["chest"]) && has(t, ["pain*", "hurt*", "tight*", "pressure", "crush*", "heavy"]) &&
                has(t, ["arm", "arms", "jaw", "sweat*", "nause*", "breath*", "dizzy", "faint*", "left"]) }),
            Rule(any: ["brustschmerz*", "douleur thoracique", "oppression thoracique", "having a heart attack", "having a stroke",
                       "cant breathe", "cannot breathe", "cant breath", "can not breathe", "cant catch my breath", "struggling to breathe",
                       "hard to breathe", "difficulty breathing", "trouble breathing", "gasping for air", "choking", "throat is closing",
                       "throat closing", "lips are blue", "lips turning blue", "narrive pas a respirer", "peux pas respirer",
                       "kann nicht atmen", "keine luft", "no puedo respirar",
                       "fainted", "fainting", "feel faint", "feeling faint", "passed out", "pass out", "passing out", "blacked out",
                       "lost consciousness", "unconscious", "collapsed", "evanoui*", "ohnmacht*", "me desmaye", "desmayo",
                       "face droop*", "face is drooping", "drooping face", "droopy face", "slurred speech", "slurring", "cant speak properly",
                       "cant move my arm", "cant move my leg", "sudden confusion", "suddenly confused", "worst headache", "seizure*",
                       "coughing blood", "coughing up blood", "vomiting blood", "overdose*", "overdosed", "too many pills", "anaphyla*",
                       "avc", "schlaganfall", "derrame cerebral", "ictus"],
                 unless: ["what if i", "in a movie"]),
            Rule(near: (["short of breath", "breathless", "out of breath"], ["rest", "resting", "sitting", "lying", "sudden*", "worse", "chest", "stairs"], 4),
                 unless: ["run", "running", "sprint*", "interval*", "hiit", "workout", "race"]),
            Rule(near: (["one side", "left side", "right side", "half my face", "one arm", "one leg"], ["weak*", "numb*", "droop*", "cant feel", "tingl*", "paraly*"], 4)),
            Rule(any: ["heart attack"], unless: ["prevent*", "risk", "chance*", "avoid*", "after my", "history"]),
            Rule(any: ["stroke"],
                 unless: ["breast*", "back", "backstroke", "freestyle", "swim*", "row*", "paddl*", "rate", "count", "technique", "crawl",
                          "butterfly", "golf", "putt*", "tennis", "strokes", "prevent*", "risk", "pedal*"]),
            Rule(any: ["stopped breathing", "not breathing", "stop breathing"], unless: ["sleep*", "night", "asleep", "snor*", "nap*", "bed"]),
        ]),
        (.minor, [
            Rule(custom: { t in
                for i in t.indices {
                    guard let n = Int(t[i]), (5...17).contains(n) else { continue }
                    let prev1 = i > 0 ? t[i - 1] : "", prev2 = i > 1 ? t[i - 2] : ""
                    let next = i + 1 < t.count ? t[i + 1] : "."
                    let next2 = i + 2 < t.count ? t[i + 2] : "."
                    let firstPerson = prev1 == "im" || (prev2 == "i" && prev1 == "am") || prev1 == "aged" || prev1 == "age" ||
                                      (prev2 == "i" && prev1 == "turned") || (prev2 == "age" && prev1 == "is")
                    if firstPerson && !numberUnits.contains(next) { return true }
                    if ((next == "years" || next == "year" || next == "yrs" || next == "yr") && next2 == "old") || next == "yo" {
                        let before = t[max(0, i - 3)..<i]
                        if !before.contains(where: { ["my", "his", "her", "our", "their", "a", "for", "was", "when"].contains($0) }) { return true }
                    }
                }
                return false }),
            Rule(any: ["im a teen*", "i am a teen*", "im in high school", "i am in high school", "im in middle school", "i am in middle school",
                       "im under 18", "i am under 18", "im not 18", "im a minor", "i am a minor", "my parents wont let me"]),
        ]),
        (.eatingDisorder, [
            Rule(near: (["burn off", "burn it off", "burn that off", "work off", "work it off"],
                        ["ate", "eaten", "eat", "food", "meal*", "dinner", "lunch", "breakfast", "yesterday", "calorie*", "kcal", "pizza",
                         "cake", "dessert", "snack*", "binge*", "that", "it", "everything", "last night", "plan"], 6)),
            Rule(any: ["ate too much", "eaten too much", "eat too much", "stop eating", "stop myself eating", "stop myself from eating",
                       "not eating anything", "not been eating", "havent been eating", "havent eaten", "skip meals", "skipping meals", "skip dinner",
                       "skip lunch", "starve myself", "starving myself", "starve to", "starvation", "purge*",
                       "purging", "throw up after", "make myself sick", "make myself throw up", "make myself vomit", "laxative*",
                       "binge eat*", "binged on", "binging on", "bingeing on", "binge on", "a binge", "earn my food", "earn dinner", "earn my dinner", "deserve to eat", "feel fat", "feel so fat", "im fat",
                       "hate my body", "hate how i look", "too fat", "disgusting body", "water fast*", "dry fast*", "eat nothing",
                       "eating nothing", "anorex*", "bulimi*", "pro ana"]),
            Rule(custom: { t in   // very low intake numbers, e.g. "eat 800 calories"
                for i in t.indices {
                    guard let n = Int(t[i]), n > 0, n < 1200, i + 1 < t.count, ["kcal", "calories", "cal", "cals"].contains(t[i + 1]) else { continue }
                    if has(t, ["eat", "eating", "diet*", "intake", "meal*"]) { return true }
                }
                return false }),
        ]),
        (.medication, [
            Rule(any: medWords, unless: ["too many pills"]),
            Rule(near: (["magnesium", "creatine", "ashwagandha", "supplement*", "vitamin*", "caffeine pill*", "pre workout", "preworkout",
                         "iron", "zinc", "cbd", "thc"], ["much", "dose", "dosage", "take", "taking", "mg", "grams", "gram", "daily", "per day", "stop", "start"], 5)),
            Rule(near: (["alcohol", "booze", "wine", "beer", "whisky", "whiskey", "vodka", "drink", "drinking", "drunk", "nightcap",
                         "weed", "cannabis", "edible", "edibles", "joint", "smoke"],
                        ["to sleep", "for sleep", "sleep aid", "help me sleep", "help sleep", "helps sleep", "helps me sleep", "fall asleep",
                         "get to sleep", "knock me out", "sleep better", "nightcap"], 6),
                 unless: ["water", "tea", "milk", "coffee", "caffeine", "electrolyte*", "juice", "cherry"]),
        ]),
        (.threshold, [
            Rule(near: (metricWords, ["dangerous", "danger", "unsafe", "worry", "worried", "worrying", "concerning", "critical", "deadly",
                                      "lethal", "alarming", "scary", "emergency", "normal range", "healthy range", "cut off", "cutoff",
                                      "threshold"], 9)),
            Rule(near: (["too low", "too high", "what is normal", "whats normal", "how low", "how high", "what level"], metricWords, 5),
                 unless: ["zone*", "target", "strain"]),
        ]),
        (.diagnosis, [
            Rule(any: diseaseHard),
            Rule(near: (["do i have", "have i got", "could i have", "might i have", "do you think i have", "could this be", "could it be",
                         "is this", "is it", "sign of", "signs of", "symptom of", "symptoms of", "think i have", "risk of"], diseaseSoft, 5),
                 unless: ["time", "sick of"]),
            Rule(any: ["whats wrong with me", "what is wrong with me", "something wrong with me", "is something wrong", "diagnos*",
                       "should i see a doctor", "should i go to the doctor", "do i need a doctor", "do i need to see a doctor",
                       "palpitation*", "heart skipping", "skipped beat*", "skipping beats", "irregular heart*", "heart is racing",
                       "racing heart", "heart pounding", "dizzy", "dizziness", "lightheaded", "light headed", "vertigo", "fever",
                       "blood in", "numbness", "tingling", "wheez*", "snoring", "snore", "pauses in breathing", "stop breathing",
                       "stopped breathing", "gasping", "am i sick", "am i ill", "am i getting sick", "am i getting ill", "sign of something",
                       "signs of something", "something serious"]),
            Rule(custom: { t in   // "is my heart ok?" but not "is my heart rate ok?"
                let words = ["ok", "okay", "healthy", "fine", "normal", "alright", "wrong", "problem", "problems", "damaged", "issue", "issues", "weak", "strong"]
                for i in t.indices where t[i] == "heart" && (i + 1 >= t.count || t[i + 1] != "rate") {
                    if t[max(0, i - 3)..<min(t.count, i + 4)].contains(where: words.contains) { return true }
                }
                return false }),
        ]),
        (.pain, [
            Rule(near: (bodyParts, painWords, 3), unless: ["no pain"]),
            Rule(any: ["injur*", "sprain*", "torn", "tore my", "fracture*", "broke my", "pulled a muscle", "pulled my", "tendinitis",
                       "tendonitis", "shin splints", "stress fracture", "it hurts", "hurts when", "hurts to", "in pain", "painful"]),
        ]),
        (.weightTarget, [
            Rule(any: ["how many calories", "calorie target", "calorie goal", "calorie deficit", "calorie budget", "calorie limit",
                       "calories to lose", "calories should i", "kcal should i", "lose weight", "losing weight", "lose fat", "weight loss",
                       "target weight", "goal weight", "ideal weight", "fasting", "cut weight", "make weight", "calorie deficit", "caloric deficit",
                       "in a deficit", "macros",
                       "maigrir", "abnehmen", "adelgazar", "perder peso"]),
            Rule(custom: { t in
                for i in t.indices where ["lose", "drop", "shed", "cut"].contains(t[i]) {
                    for j in (i + 1)..<min(t.count, i + 4) where ["kg", "kgs", "kilo", "kilos", "lb", "lbs", "pound", "pounds", "stone"].contains(t[j]) { return true }
                }
                return false }),
        ]),
        (.jailbreak, [
            Rule(near: (["ignore", "forget your", "forget all", "disregard", "override", "bypass"], ["rule*", "instruction*", "guideline*", "prompt", "previous", "safety", "restriction*", "limit*"], 4)),
            Rule(near: (["act as", "acting as", "pretend", "role play", "roleplay", "you are", "youre", "be my"],
                        ["doctor", "physician", "cardiologist", "nurse", "medic", "pharmacist", "gp", "therapist", "psychiatrist"], 4)),
            Rule(any: ["developer mode", "dan mode", "jailbreak*", "system prompt", "no restrictions", "without restrictions", "unfiltered"]),
        ]),
        (.healthWrite, [
            Rule(near: (["write", "save", "add", "log", "record", "enter", "put", "change", "edit", "update", "set", "delete", "remove",
                         "erase", "overwrite", "fake", "sync"], ["into health", "in health", "to health", "into apple health", "in apple health",
                                                                 "to apple health", "healthkit", "health app", "health data", "from health"], 6)),
            Rule(any: ["set my * to", "set my * * to", "set my * * * to", "change my * to", "change my * * to", "change my * * * to"],
                 unless: ["goal", "target", "alarm", "reminder*", "bedtime", "schedule", "plan", "style", "notes", "units"]),
        ]),
        (.condition, [
            Rule(any: ["pregnan*", "expecting a baby", "postpartum", "after giving birth", "diabetic", "diabetes", "asthma*", "heart condition",
                       "pacemaker", "hypertension", "high blood pressure", "blood pressure", "copd", "epilep*", "cancer", "chemo*", "surgery",
                       "long covid", "my doctor said", "my cardiologist", "enceinte", "schwanger", "embarazada"]),
        ]),
    ]

    private static func matches(_ r: Rule, _ t: [String]) -> Bool {
        if !r.unless.isEmpty, has(t, r.unless) { return false }
        if !r.any.isEmpty, has(t, r.any) { return true }
        if let n = r.near {
            let a = n.a.flatMap { starts(of: $0, in: t) }, b = n.b.flatMap { starts(of: $0, in: t) }
            if a.contains(where: { i in b.contains { j in i != j && abs(i - j) <= n.window } }) { return true }
        }
        if let c = r.custom, c(t) { return true }
        return false
    }

    private static func has(_ t: [String], _ phrases: [String]) -> Bool { phrases.contains { !starts(of: $0, in: t).isEmpty } }

    /// Start indices of a phrase ("beta blocker*") in the token list.
    private static func starts(of phrase: String, in t: [String]) -> [Int] {
        let p = phrase.split(separator: " ").map(String.init)
        guard !p.isEmpty, p.count <= t.count else { return [] }
        var out: [Int] = []
        for i in 0...(t.count - p.count) where zip(p, t[i..<(i + p.count)]).allSatisfy({ tokenMatch($0, $1) }) { out.append(i) }
        return out
    }

    private static func tokenMatch(_ p: String, _ t: String) -> Bool {
        p.hasSuffix("*") ? t.hasPrefix(p.dropLast()) : p == t
    }

    // MARK: - Text helpers

    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
    }

    /// Lowercase, diacritics folded, apostrophes dropped ("can't" → "cant"), digit groups joined ("1,000" → "1000"),
    /// sentence punctuation kept as "." tokens, everything else split.
    static func tokenize(_ text: String) -> [String] {
        let chars = Array(fold(text))
        var tokens: [String] = [], cur = ""
        func flush() { if !cur.isEmpty { tokens.append(cur); cur = "" } }
        for (i, c) in chars.enumerated() {
            if c.isLetter || c.isNumber { cur.append(c); continue }
            if "'’ʼ`´".contains(c) { continue }
            if (c == "," || c == ".") && cur.last?.isNumber == true && i + 1 < chars.count && chars[i + 1].isNumber { continue }
            flush()
            if ".!?;\n".contains(c), tokens.last != "." { tokens.append(".") }
        }
        flush()
        return tokens
    }

    // MARK: - postCheck helpers

    private static let bannedPatterns: [(String, NSRegularExpression)] = [
        ("diagnose", #"\bdiagnos\w*"#), ("detect", #"\bdetect\w*"#), ("apnea", #"\bapno?ea\w*"#), ("AFib", #"\ba-?\s?fib\b|\batrial fibrillation"#),
        ("hypoxia", #"\bhypox\w*"#), ("arrhythmia", #"\barr?h?ythmi\w*"#), ("abnormal", #"\babnormal\w*"#), ("danger", #"\bdanger\w*"#),
        ("dose", #"\bdos(e|es|age|ages|ing)\b"#), ("mg", #"\d\s*mg\b|\bmg\b"#), ("injury", #"\binjur\w*"#), ("below target", #"\bbelow (your |the )?target\b"#),
        ("calorie target", #"\bcalori\w*\s+(target|goal|deficit|budget|limit|allowance|intake)\b"#), ("deficit", #"\b(calori\w*|caloric|energy)\s+(deficit|surplus)\b|\bin a (calorie |caloric )?(deficit|surplus)\b"#),
        ("weight target", #"\b(lose|drop|shed|cut)\s+(about\s+|around\s+)?\d+([.,]\d+)?\s*(kg|kilos?|kilograms?|lbs?|pounds?|stone)\b"#),
        ("weight target", #"\b(target|goal|ideal)\s+weight\b|\bweight[- ]?(loss\s+)?(target|goal)\b"#),
        ("calorie target", #"\b(eat|eating|consume)\s+(about\s+|around\s+|under\s+|less than\s+|only\s+)?\d[\d.,]*\s*(k?cal|calories)\b"#),
        ("compensatory", #"\b(burn|work) (it |that |this |them )?off\b|\bearn (your|a|the) (food|meal|dinner|lunch|treat|snack)"#),
        ("fasting", #"\bfasting\b"#),
    ].map { ($0.0, try! NSRegularExpression(pattern: $0.1, options: [.caseInsensitive])) }

    private static let numberRE = try! NSRegularExpression(pattern: #"\d+(?:[.,]\d+)*"#)
    private static let exemptPrefixes: Set<String> = ["spo", "vo", "o", "co", "hba"]

    /// Canonical numbers in a string: "58 bpm" → ["58"], "7 h 12" → ["7","12"], "7,5" → ["7.5"], "1,000" → ["1000"].
    /// With `exemptTerms`, digits that are part of a name (SpO2, VO2 max, Zone 2, Z2) are skipped.
    static func numbers(in s: String, exemptTerms: Bool) -> [String] {
        let ns = s as NSString
        return numberRE.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let raw = ns.substring(with: m.range)
            let c = canonical(raw)
            if exemptTerms {
                let before = ns.substring(to: m.range.location)
                let letters = String(before.reversed().prefix { $0.isLetter }.reversed()).lowercased()
                let small = (Double(c) ?? 99) <= 5
                if exemptPrefixes.contains(letters) || (letters == "z" && small) { return nil }
                if small, before.lowercased().hasSuffix("zone ") { return nil }
            }
            return c
        }
    }

    /// "07" → "7", "7,50" → "7.5", "7.0" → "7", "1,000" / "1.000" → "1000".
    static func canonical(_ raw: String) -> String {
        var s = raw
        if s.range(of: #"^\d{1,3}([.,]\d{3})+$"#, options: .regularExpression) != nil, !(s.filter { $0 == "." || $0 == "," }.count == 1 && s.hasPrefix("0")) {
            s = s.filter(\.isNumber)
        } else {
            if s.contains(".") && s.contains(",") { s = s.replacingOccurrences(of: ",", with: "") }
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        var intPart = String(parts[0].drop { $0 == "0" })
        if intPart.isEmpty { intPart = "0" }
        guard parts.count == 2 else { return parts.count > 2 ? s : intPart }
        let frac = String(parts[1].reversed().drop { $0 == "0" }.reversed())
        return frac.isEmpty ? intPart : intPart + "." + frac
    }

    /// An allowed decimal also allows its rounded forms ("58.4" allows "58"; "7.25" allows "7.3" and "7").
    private static func variants(_ c: String) -> [String] {
        guard c.contains("."), let d = Double(c) else { return [c] }
        return [c, canonical(String(format: "%.1f", d)), canonical(String(format: "%.0f", d)), canonical(String(Int(d)))]
    }
}
