import Foundation

// v1.1 Coach · reviewed session library (CoachLibrary.json, bundled). Owner: agent K.
// The coach only selects a session and sets its length; it never writes exercises (research/v11-05 §Library).
// Every plan ends with the safety cue "Stop if you feel pain or dizziness." on its last step.

extension IntensityCap {
    /// rest < easy < moderate < any.
    var libraryRank: Int {
        switch self {
        case .rest: return 0
        case .easy: return 1
        case .moderate: return 2
        case .any: return 3
        }
    }

    /// The stricter of two caps.
    func capped(at other: IntensityCap) -> IntensityCap { libraryRank <= other.libraryRank ? self : other }

    /// Plain words for copy: "light only", "easy", "steady", "any intensity".
    var plainWord: String {
        switch self {
        case .rest: return "light only"
        case .easy: return "easy"
        case .moderate: return "steady"
        case .any: return "any intensity"
        }
    }

    /// Longest session the cap allows (R1: ≤ 30 min, R2: ≤ 45 min).
    var maxMinutes: Int {
        switch self {
        case .rest: return 30
        case .easy: return 45
        case .moderate: return 120
        case .any: return 150
        }
    }

    static func from(libraryText s: String) -> IntensityCap {
        switch s.lowercased() {
        case "rest": return .rest
        case "easy": return .easy
        case "moderate": return .moderate
        default: return .any
        }
    }
}

enum CoachLibrary {

    // MARK: Schema (CoachLibrary.json)

    struct Step: Codable, Hashable {
        let label: String
        var cue: String?
        /// Fixed duration.
        var minutes: Double?
        /// Takes whatever time is left after the fixed steps (one per session at most).
        var fill: Bool?
        /// Heart-rate zone 1–5 (% of max HR), shown in bpm.
        var zone: Int?
        /// Rep text ("8–12", "6 each side") or, for timed steps, a description ("4 × 4 min hard, 3 min easy").
        var reps: String?
        var sets: Int?
        /// Seconds one set takes including rest (default 75).
        var setSec: Int?
        var holdSec: Int?
        var sides: Bool?
        /// Breathing: seconds of [in, hold, out, hold].
        var pattern: [Int]?
        var rounds: Int?
    }

    struct Session: Codable, Hashable, Identifiable {
        let id: String
        let name: String
        /// breath · winddown · recovery · mobility · walk · run · ride · row · cardio · strength
        let kind: String
        /// Highest readiness cap needed: rest · easy · moderate · any.
        let intensity: String
        let modes: [String]
        let minutes: [Int]
        let zones: [Int]
        let strainEstimate: [Double]
        let recoveryMin: Int
        /// [] = no gear. Otherwise any of: dumbbells, bike, rower, gym, pool.
        let equipment: [String]
        let indoor: Bool
        let focus: [String]?
        let summary: String
        let steps: [Step]
        /// fever · chestSymptoms · unwell
        let avoidIf: [String]
        let source: String

        var cap: IntensityCap { IntensityCap.from(libraryText: intensity) }
        var minMinutes: Int { minutes.first ?? 10 }
        var maxMinutes: Int { minutes.last ?? minMinutes }
        var maxZone: Int { zones.max() ?? 0 }
        var isCardio: Bool { ["walk", "run", "ride", "row", "cardio"].contains(kind) }
    }

    private struct FileData: Codable {
        let version: Int
        let safetyCue: String
        let sessions: [Session]
    }

    static let safetyCue = "Stop if you feel pain or dizziness."

    /// All reviewed sessions, loaded once from the app bundle.
    static let sessions: [Session] = {
        guard let url = Bundle.main.url(forResource: "CoachLibrary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(FileData.self, from: data) else {
            assertionFailure("CoachLibrary.json missing or invalid")
            return []
        }
        return file.sessions
    }()

    static func session(id: String) -> Session? { sessions.first { $0.id == id } }

    // MARK: Find

    /// Contract API (DESIGN_SPEC_v1.1 §8). Every library session allowed by `cap` and `equipment`
    /// (breathing and wind-down routines excluded: ask for them by kind), scaled to `minutes` and
    /// sorted best first; the first three are of different kinds.
    static func find(cap: IntensityCap, minutes: Int, equipment: String?) -> [CoachPlan] {
        find(cap: cap, minutes: minutes, equipment: equipment, kind: nil)
    }

    /// Richer lookup for tools and template replies.
    /// - kind: a session kind ("strength", "run", …), "cardio" (walk/run/ride/row/cardio), "breathing"/"breath",
    ///   "winddown", "mobility" (also matches stretches), "recovery"/"rest". nil = training sessions.
    /// - focus: optional word matched against `focus` ("hips", "desk", "runners", "sleep").
    /// - avoid: context flags ("unwell", "fever", "chestSymptoms") that exclude sessions listing them in `avoidIf`.
    static func find(cap: IntensityCap, minutes: Int, equipment: String?, kind: String?,
                     focus: String? = nil, maxZone: Int? = nil, avoid: Set<String> = [],
                     indoorOnly: Bool = false, age: Int? = nil, limit: Int? = nil) -> [CoachPlan] {
        let gear = allowedGear(equipment)
        let want = max(2, minutes)
        let candidates = sessions.filter { s in
            guard s.cap.libraryRank <= cap.libraryRank else { return false }
            guard Set(s.equipment).isSubset(of: gear) else { return false }
            guard avoid.isDisjoint(with: s.avoidIf) else { return false }
            if indoorOnly && !s.indoor { return false }
            if let maxZone, s.maxZone > maxZone { return false }
            if !matches(kind: kind, s) { return false }
            if let f = focus?.lowercased(), !f.isEmpty,
               !(s.focus ?? []).contains(where: { $0.contains(f) }) && !s.name.lowercased().contains(f) { return false }
            // Long sessions only up to what the cap allows (R1 ≤ 30 min, R2 ≤ 45 min).
            return s.minMinutes <= cap.maxMinutes
        }
        let ranked = candidates.sorted { a, b in
            // Sessions that use the person's own gear rank a little higher.
            let sa = score(a, cap: cap, minutes: want) - (a.equipment.isEmpty ? 0 : 3)
            let sb = score(b, cap: cap, minutes: want) - (b.equipment.isEmpty ? 0 : 3)
            if sa != sb { return sa < sb }
            let ma = abs((a.minMinutes + a.maxMinutes) / 2 - want), mb = abs((b.minMinutes + b.maxMinutes) / 2 - want)
            return ma == mb ? a.id < b.id : ma < mb
        }
        // Diversity: best session of each kind first (only if its length fits within 10 min), then the rest.
        var head: [Session] = [], tail: [Session] = [], kinds: Set<String> = []
        for s in ranked {
            let fits = want >= s.minMinutes - 10 && want <= s.maxMinutes + 10
            if head.count < 3, fits, !kinds.contains(s.kind) { head.append(s); kinds.insert(s.kind) } else { tail.append(s) }
        }
        let ordered = head + tail
        let plans = ordered.map { plan($0, minutes: min(want, cap.maxMinutes), age: age) }
        if let limit { return Array(plans.prefix(limit)) }
        return plans
    }

    /// Lower is better: a session at the cap's own level fits a ready day best; then closeness of length.
    private static func score(_ s: Session, cap: IntensityCap, minutes: Int) -> Int {
        let gap = cap.libraryRank - s.cap.libraryRank
        let fit: Int
        if minutes < s.minMinutes { fit = s.minMinutes - minutes }
        else if minutes > s.maxMinutes { fit = minutes - s.maxMinutes }
        else { fit = 0 }
        return gap * 12 + fit
    }

    private static func matches(kind: String?, _ s: Session) -> Bool {
        guard let k = kind?.lowercased(), !k.isEmpty, k != "any" else {
            return !["breath", "winddown"].contains(s.kind)
        }
        switch k {
        case "cardio": return s.isCardio
        case "breath", "breathing", "breathe": return s.kind == "breath"
        case "winddown", "wind-down", "sleep": return s.kind == "winddown" || (s.kind == "breath" && (s.focus ?? []).contains("sleep"))
        case "mobility", "stretch", "stretching", "yoga": return s.kind == "mobility"
        case "recovery", "rest": return s.kind == "recovery" || (s.cap == .rest && s.kind != "breath" && s.kind != "winddown")
        case "intervals", "hiit": return s.cap == .any
        case "bike", "cycling": return s.kind == "ride"
        default: return s.kind == k || s.modes.contains(k)
        }
    }

    /// Gear the person has. nil / "None" = bodyweight only; "Dumbbells"; "Gym" = everything.
    static func allowedGear(_ equipment: String?) -> Set<String> {
        let e = (equipment ?? "").lowercased()
        var gear: Set<String> = []
        if e.contains("gym") { gear = ["dumbbells", "bike", "rower", "gym", "pool"] }
        if e.contains("dumbbell") || e.contains("weights") || e.contains("kettlebell") { gear.insert("dumbbells") }
        if e.contains("bike") || e.contains("cycl") || e.contains("trainer") { gear.insert("bike") }
        if e.contains("rower") || e.contains("rowing") { gear.insert("rower") }
        if e.contains("pool") || e.contains("swim") { gear.insert("pool") }
        return gear
    }

    // MARK: Plan building

    /// Builds a runnable plan from a session, scaled as close to `minutes` as its range allows.
    static func plan(_ s: Session, minutes requested: Int, age: Int? = nil) -> CoachPlan {
        let targetMin = min(max(requested, s.minMinutes), s.maxMinutes)
        let target = Double(targetMin * 60)
        let maxHR = age.map { 208 - 0.7 * Double($0) } ?? 185

        func unitSeconds(_ st: Step) -> Double? {
            if st.minutes != nil || st.fill == true { return nil }
            if let p = st.pattern { return Double(max(p.reduce(0, +), 1)) }
            if let h = st.holdSec { return Double(h * (st.sides == true ? 2 : 1) + 10) }
            if st.reps != nil { return Double(st.setSec ?? 75) }
            return nil
        }
        func baseCount(_ st: Step) -> Double {
            if st.pattern != nil { return Double(st.rounds ?? 10) }
            return Double(st.sets ?? 1)
        }

        let fixed = s.steps.reduce(0.0) { $0 + ($1.fill == true ? 0 : ($1.minutes ?? 0) * 60) }
        let hasFill = s.steps.contains { $0.fill == true }
        let scalableBase = s.steps.reduce(0.0) { acc, st in acc + (unitSeconds(st).map { $0 * baseCount(st) } ?? 0) }

        // One shared factor for sets / breathing rounds; fill steps absorb the rest instead.
        var k = 1.0
        if !hasFill, scalableBase > 0 {
            k = min(max((target - fixed) / scalableBase, 0.5), 3)
        }
        let counts: [Int] = s.steps.map { st in
            guard unitSeconds(st) != nil else { return 0 }
            let raw = baseCount(st) * k
            // Sets stay within base … base + 2 (max 6); breathing keeps at least 3 rounds.
            if st.pattern != nil { return max(3, Int(raw.rounded())) }
            let base = st.sets ?? 1
            return min(max(Int(raw.rounded()), 1), min(base + 2, 6))
        }
        let scaled = zip(s.steps, counts).reduce(0.0) { acc, pair in
            acc + (unitSeconds(pair.0).map { $0 * Double(pair.1) } ?? 0)
        }
        let fillSeconds = max(60, target - fixed - scaled)

        var total = 0.0
        var out: [PlanStep] = []
        for (i, st) in s.steps.enumerated() {
            var name = st.label
            var seconds: Int? = nil
            var reps: String? = nil
            var cue = st.cue ?? ""
            if st.fill == true || st.minutes != nil {
                let sec = st.fill == true ? fillSeconds : (st.minutes ?? 0) * 60
                seconds = Int(sec.rounded())
                reps = st.reps
                total += sec
            } else if let p = st.pattern {
                let n = counts[i]
                seconds = p.reduce(0, +) * n
                reps = "\(n) breaths"
                cue = [cue, patternText(p)].filter { !$0.isEmpty }.joined(separator: " ")
                total += Double(seconds ?? 0)
            } else if let h = st.holdSec {
                let n = counts[i]
                let each = st.sides == true ? " each side" : ""
                seconds = h * (st.sides == true ? 2 : 1) * n
                reps = n > 1 ? "\(n) × \(h) s\(each)" : "\(h) s\(each)"
                total += (unitSeconds(st) ?? 0) * Double(n)
            } else if let r = st.reps {
                let n = counts[i]
                reps = n > 1 ? "\(n) × \(r)" : r
                total += (unitSeconds(st) ?? 0) * Double(n)
            }
            if let z = st.zone { cue = [cue, zoneText(z, maxHR: maxHR)].filter { !$0.isEmpty }.joined(separator: " ") }
            if i == s.steps.count - 1, !cue.contains(safetyCue) {
                cue = cue.isEmpty ? safetyCue : cue + " " + safetyCue
            }
            if name.isEmpty { name = "Step \(i + 1)" }
            out.append(PlanStep(name: name, seconds: seconds, reps: reps, cue: cue))
        }
        let minutes = max(1, Int((total / 60).rounded()))
        return CoachPlan(id: s.id, title: s.name, minutes: minutes, steps: out)
    }

    /// "Zone 2 · 111–129 bpm." from % of max HR (Z1 50–60 … Z5 90–100).
    static func zoneText(_ zone: Int, maxHR: Double) -> String {
        let z = min(max(zone, 1), 5)
        let lo = Int((maxHR * (0.4 + 0.1 * Double(z))).rounded())
        let hi = z == 5 ? Int(maxHR.rounded()) : Int((maxHR * (0.5 + 0.1 * Double(z))).rounded()) - 1
        return "Zone \(z) · \(lo)–\(hi) bpm."
    }

    /// Heart-rate zones in bpm, Z1…Z5.
    static func zonesBPM(age: Int?) -> [ClosedRange<Int>] {
        let maxHR = age.map { 208 - 0.7 * Double($0) } ?? 185
        return (1...5).map { z in
            let lo = Int((maxHR * (0.4 + 0.1 * Double(z))).rounded())
            let hi = z == 5 ? Int(maxHR.rounded()) : Int((maxHR * (0.5 + 0.1 * Double(z))).rounded()) - 1
            return lo...hi
        }
    }

    /// "In 4 s, hold 4 s, out 4 s, hold 4 s."
    static func patternText(_ p: [Int]) -> String {
        let names = ["in", "hold", "out", "hold"]
        let parts = p.prefix(4).enumerated().compactMap { i, v in v > 0 ? "\(names[i]) \(v) s" : nil }
        guard let first = parts.first else { return "" }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + parts.dropFirst()).joined(separator: ", ") + "."
    }
}
