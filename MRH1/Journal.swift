import Foundation
import Observation

/// One day of journal tags. `day` is the local calendar day at midnight.
struct JournalEntry: Codable, Identifiable, Hashable {
    var day: Date
    var tags: Set<String>
    var id: Date { day }
}

/// Journal tags ("+" on Today) and the "Discoveries" they unlock (research/02 Decision 9).
///
/// Persisted as JSON in Application Support (`journal.json`): the entries, custom tags, and a small
/// log of each day's sleep score / recovery so discoveries keep working beyond the 14-day history.
/// Demo mode keeps everything in memory with deterministic sample tags, and never writes the file.
@Observable
@MainActor
final class JournalStore {

    static let defaultTags = [
        "Alcohol", "Late meal", "Caffeine after 2 pm", "Hard workout", "Stressful day",
        "Screen in bed", "Travel", "Feeling unwell", "Meditation", "Nap"
    ]

    /// Tagged days needed before discoveries appear.
    static let discoveryThreshold = 5

    /// The most recently created store, so HealthStore can hand it each refresh's history.
    private(set) static weak var current: JournalStore?

    /// Tags offered in the sheet (defaults + custom), in display order.
    private(set) var tags: [String] = JournalStore.defaultTags
    /// All tagged days, oldest first.
    private(set) var entries: [JournalEntry] = []
    /// Per-day scores remembered from HealthStore history (local day → values).
    private(set) var scoreLog: [Date: DayScores] = [:]

    struct DayScores: Codable, Hashable {
        var sleepScore: Int?
        var recovery: Int?
    }

    private let persist: Bool
    private let fileURL: URL?

    init(demo: Bool = Demo.isOn) {
        persist = !demo
        fileURL = demo ? nil : Self.defaultURL()
        if demo { seedDemo() } else { load() }
        JournalStore.current = self
    }

    // MARK: Reading

    /// Tags set on the given day (any time inside it).
    func entries(for date: Date) -> Set<String> {
        let d = Self.day(date)
        return entries.first(where: { $0.day == d })?.tags ?? []
    }

    func isOn(_ tag: String, date: Date = Date()) -> Bool { entries(for: date).contains(tag) }

    /// Number of days with at least one tag.
    var taggedDays: Int { entries.filter { !$0.tags.isEmpty }.count }

    /// "2 more tagged days to unlock discoveries", nil once unlocked.
    var progressText: String? {
        let left = Self.discoveryThreshold - taggedDays
        guard left > 0 else { return nil }
        return left == 1 ? "1 more tagged day to unlock discoveries" : "\(left) more tagged days to unlock discoveries"
    }

    // MARK: Writing

    /// Flips `tag` on `date`.
    func toggle(tag: String, on date: Date = Date()) {
        toggle(tag: tag, on: !isOn(tag, date: date), date: date)
    }

    /// Sets `tag` to `isOn` for `date`.
    func toggle(tag: String, on isOn: Bool, date: Date = Date()) {
        let d = Self.day(date)
        var list = entries
        if let i = list.firstIndex(where: { $0.day == d }) {
            if isOn { list[i].tags.insert(tag) } else { list[i].tags.remove(tag) }
            if list[i].tags.isEmpty { list.remove(at: i) }
        } else if isOn {
            list.append(JournalEntry(day: d, tags: [tag]))
            list.sort { $0.day < $1.day }
        }
        entries = list
        save()
    }

    /// Adds a custom tag to the list (trimmed, case-insensitive de-dup).
    func addTag(_ name: String) {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !tags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else { return }
        tags.append(t)
        save()
    }

    /// Removes a tag from the list and from every day.
    func removeTag(_ name: String) {
        tags.removeAll { $0 == name }
        entries = entries.compactMap { e in
            var e = e
            e.tags.remove(name)
            return e.tags.isEmpty ? nil : e
        }
        save()
    }

    // MARK: Discoveries

    /// Remember each day's scores (HealthStore calls this after every refresh).
    func attach(history: [DaySummary]) {
        var log = scoreLog
        for h in history where h.sleepScore != nil || h.recovery != nil {
            log[Self.day(h.date)] = DayScores(sleepScore: h.sleepScore, recovery: h.recovery)
        }
        guard log != scoreLog else { return }
        scoreLog = log
        save()
    }

    /// After ≥ 5 tagged days: one sentence per tag whose next-morning scores differ from untagged days.
    /// A tag on day D is compared with the night ending on D + 1 (sleep score) and D + 1 recovery.
    /// e.g. "On late meal days, your sleep score averages 8 lower."
    var discoveries: [String] {
        guard taggedDays >= Self.discoveryThreshold else { return [] }
        let cal = Calendar.current
        func next(_ d: Date) -> DayScores? {
            cal.date(byAdding: .day, value: 1, to: d).flatMap { scoreLog[$0] }
        }
        let scoredDays = scoreLog.keys.compactMap { cal.date(byAdding: .day, value: -1, to: $0) }
        var found: [(String, Double)] = []
        for tag in tags {
            let tagged = Set(entries.filter { $0.tags.contains(tag) }.map(\.day))
            guard tagged.count >= 2 else { continue }
            let untagged = scoredDays.filter { !tagged.contains($0) }
            for (label, key) in [("sleep score", \DayScores.sleepScore), ("recovery", \DayScores.recovery)] {
                let a = tagged.compactMap { next($0)?[keyPath: key] }.map(Double.init)
                let b = untagged.compactMap { next($0)?[keyPath: key] }.map(Double.init)
                guard a.count >= 2, b.count >= 2 else { continue }
                let diff = a.reduce(0, +) / Double(a.count) - b.reduce(0, +) / Double(b.count)
                let n = Int(abs(diff).rounded())
                guard n >= 3 else { continue }
                let unit = label == "recovery" ? " points" : ""
                found.append(("On \(tag.lowercased()) days, your \(label) averages \(n)\(unit) \(diff > 0 ? "higher" : "lower").", abs(diff)))
            }
        }
        return found.sorted { $0.1 > $1.1 }.prefix(3).map(\.0)
    }

    // MARK: Persistence

    private struct FileData: Codable {
        var tags: [String]
        var entries: [JournalEntry]
        var scores: [Date: DayScores]
    }

    private static func defaultURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("journal.json")
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(FileData.self, from: data) else { return }
        tags = f.tags.isEmpty ? Self.defaultTags : f.tags
        entries = f.entries.sorted { $0.day < $1.day }
        scoreLog = f.scores
    }

    private func save() {
        guard persist, let url = fileURL else { return }
        let f = FileData(tags: tags, entries: entries, scores: scoreLog)
        if let data = try? JSONEncoder().encode(f) { try? data.write(to: url, options: .atomic) }
    }

    static func day(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

    // MARK: Demo

    /// Deterministic sample tags over the last 14 days (days ago → tags), enough to unlock discoveries.
    private func seedDemo() {
        let plan: [Int: Set<String>] = [
            13: ["Late meal"], 11: ["Alcohol", "Late meal"], 10: ["Hard workout"], 8: ["Late meal"],
            6: ["Stressful day"], 4: ["Hard workout"], 3: ["Alcohol"], 2: ["Late meal", "Stressful day"],
            1: ["Hard workout"]
        ]
        let today = Self.day(Demo.now)
        entries = plan.compactMap { ago, t in
            Calendar.current.date(byAdding: .day, value: -ago, to: today).map { JournalEntry(day: $0, tags: t) }
        }.sorted { $0.day < $1.day }
    }
}
