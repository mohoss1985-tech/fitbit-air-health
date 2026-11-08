import SwiftUI

// v1.1 Coach · UI support: greeting sentence, data-generated starters, flow layout, preview data.
// Owner: agent N.

// MARK: - Greeting (time-of-day aware, same hours as the Today verdict)

@MainActor
enum CoachGreeting {
    /// "Morning. Recovery 72 %, sleep 7 h 12." Only numbers MRH1 computed; never invents one.
    static func sentence(_ health: HealthStore, now: Date = Demo.now) -> String {
        let h = Calendar.current.component(.hour, from: now)
        let recovery = health.recovery.map { "recovery \($0.score) %" }
        let sleep = health.lastSleep.flatMap { $0.asleepMinutes > 0 ? "sleep \(MetricID.sleepTotal.format($0.asleepMinutes))" : nil }
        let strain = health.strain.map { String(format: "strain %.1f", locale: .current, $0.value) }

        let (word, parts): (String, [String?]) = {
            if h >= 4 && h < 12 { return ("Morning", [recovery, sleep]) }
            if h >= 12 && h < 18 { return ("Afternoon", [recovery, strain]) }
            return ("Evening", [strain, sleep])
        }()
        let found = parts.compactMap { $0 }
        guard !found.isEmpty else { return "\(word). Waiting for today’s data from Google Health." }
        let joined = found.joined(separator: ", ")
        return "\(word). " + joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }
}

// MARK: - Starters

/// One starter row on the empty Coach tab: a short topic word and a full question.
struct CoachStarter: Identifiable, Hashable {
    let topic: String
    let question: String
    let metric: MetricID?
    var id: String { question }
}

@MainActor
enum CoachStarterSource {
    /// Four data-generated starters: Recovery, Sleep, Strain, Plan. Questions come from
    /// `CoachRules.starters(health:)` (agent K); `fallback` covers an unexpected count.
    static func make(_ health: HealthStore) -> [CoachStarter] {
        let q = CoachRules.starters(health: health)
        guard q.count == 4 else { return fallback(health) }
        return [
            CoachStarter(topic: "Recovery", question: q[0], metric: nil),
            CoachStarter(topic: "Sleep", question: q[1], metric: .sleepTotal),
            CoachStarter(topic: "Strain", question: q[2], metric: nil),
            CoachStarter(topic: "Plan", question: q[3], metric: nil),
        ]
    }

    static func fallback(_ health: HealthStore) -> [CoachStarter] {
        let score = health.recovery?.score
        let sleepMin = health.lastSleep?.asleepMinutes ?? 0
        let target = Scores.todayStrainTarget(health)
        let strain = health.strain?.value

        let recovery: String = {
            guard let score else { return "How does Recovery work?" }
            if score < 34 { return "Why is my recovery low today?" }
            if score < 67 { return "What would help me recover more?" }
            return "How hard can I train today?"
        }()
        let sleep: String = {
            if sleepMin <= 0 { return "How was my sleep this week?" }
            if sleepMin < 6.5 * 60 { return "Why did I wake up tired?" }
            return "How was my sleep this week?"
        }()
        let load: String = {
            guard let strain else { return "Plan today around my recovery" }
            if strain >= target.upperBound { return "Have I done enough today?" }
            return "Plan today around my recovery"
        }()
        let plan = (score ?? 50) < 34 ? "Make me an easy 15-min session" : "Make me a 20-min workout"

        return [
            CoachStarter(topic: "Recovery", question: recovery, metric: nil),
            CoachStarter(topic: "Sleep", question: sleep, metric: .sleepTotal),
            CoachStarter(topic: "Strain", question: load, metric: nil),
            CoachStarter(topic: "Plan", question: plan, metric: nil),
        ]
    }

    /// Starters for a sheet opened about one metric.
    static func about(_ metric: MetricID) -> [CoachStarter] {
        let name = metric.info.name.lowercased()
        return [
            CoachStarter(topic: metric.info.name, question: "What does my \(name) mean?", metric: metric),
            CoachStarter(topic: "Change", question: "How has it changed this week?", metric: metric),
            CoachStarter(topic: "Action", question: "What can I do about it?", metric: metric),
        ]
    }
}

// MARK: - Flow layout (pills and chips wrap instead of scrolling, so nothing hides at AX sizes)

struct CoachFlowLayout: Layout {
    var spacing: CGFloat = Space.s
    var lineSpacing: CGFloat = Space.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let w = rows.map(\.width).max() ?? 0
        let h = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, w) } ?? w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (i, size) in zip(row.indices, row.sizes) {
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                  proposal: ProposedViewSize(width: size.width, height: size.height))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var sizes: [CGSize] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (i, sub) in subviews.enumerated() {
            var size = sub.sizeThatFits(.unspecified)
            if size.width > width { size = sub.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width && !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            row.sizes.append(size)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: - Demo / preview data

enum CoachDemo {
    static let plan = CoachPlan(
        id: "demo-20-bodyweight",
        title: "20-min bodyweight circuit",
        minutes: 20,
        steps: [
            PlanStep(name: "Warm-up march", seconds: 180, reps: nil, cue: "Easy pace, swing your arms."),
            PlanStep(name: "Squats", seconds: 45, reps: "×12", cue: "Sit back, chest up."),
            PlanStep(name: "Rest", seconds: 15, reps: nil, cue: "Breathe out slowly."),
            PlanStep(name: "Push-ups on a wall", seconds: 45, reps: "×10", cue: "Body in one straight line."),
            PlanStep(name: "Glute bridge", seconds: nil, reps: "×15", cue: "Squeeze at the top for a second."),
            PlanStep(name: "Cool-down walk", seconds: 180, reps: nil, cue: "Let your breathing settle."),
        ])

    static let messages: [CoachMessage] = {
        let now = Demo.now
        return [
            CoachMessage(id: UUID(), role: .user, date: now.addingTimeInterval(-300), reply: nil,
                         text: "Why am I tired today?"),
            CoachMessage(id: UUID(), role: .coach, date: now.addingTimeInterval(-290), reply: CoachReply(
                headline: "Short night, and your heart is still settling.",
                body: "You slept about an hour under your normal, and resting heart rate sits a little above your usual range. Keep today easy and aim for bed by 22:45.",
                pills: [
                    DataPill(metric: .sleepTotal, text: "Sleep 6 h 05 · normal 7 h 10", tier: .watch),
                    DataPill(metric: .restingHR, text: "RHR 58 · normal 54–57", tier: .watch),
                ],
                chips: ["Plan tonight’s wind-down", "Is easy cardio okay?", "Why deep sleep matters"]),
                         text: nil),
            CoachMessage(id: UUID(), role: .user, date: now.addingTimeInterval(-120), reply: nil,
                         text: "Make me a 20-min workout"),
            CoachMessage(id: UUID(), role: .coach, date: now.addingTimeInterval(-110), reply: CoachReply(
                headline: "An easy circuit that fits a moderate day.",
                body: "Bodyweight only, no jumps. Keep breathing steady; you should be able to talk.",
                pills: [DataPill(metric: .restingHR, text: "Recovery 58 %", tier: .watch)],
                chips: ["Make it shorter", "No floor work", "What about a walk?"],
                plan: plan),
                         text: nil),
        ]
    }()

    static let note = CoachNote(
        id: "demo-note",
        headline: "Room for a session. 30 min easy cardio keeps you in target.",
        body: "Strain is under your target and recovery is in range, so an easy session fits without costing tomorrow.",
        metric: nil,
        chips: ["Plan it", "Why easy?"])
}

/// Injects demo stores for #Previews.
struct CoachPreviewHost<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var health = HealthStore()
    @State private var nav = AppNav()
    @State private var journal = JournalStore()
    @State private var engine: CoachEngine = {
        let e = CoachEngine()
        e.messages = CoachDemo.messages
        return e
    }()

    var body: some View {
        content
            .environment(health)
            .environment(nav)
            .environment(journal)
            .environment(engine)
    }
}
