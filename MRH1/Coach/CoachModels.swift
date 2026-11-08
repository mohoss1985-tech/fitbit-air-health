import SwiftUI

// v1.1 Coach · shared types (DESIGN_SPEC_v1.1 §8). Owner: agent L. Names are FIXED (members may be added).

enum IntensityCap: String, Codable { case rest, easy, moderate, any }

/// "RHR 58 · normal 54–57" with a status-tier dot.
struct DataPill: Hashable {
    let metric: MetricID
    let text: String
    let tier: StatusTier?
}

struct PlanStep: Codable, Hashable {
    let name: String
    let seconds: Int?
    let reps: String?
    let cue: String
}

struct CoachPlan: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let minutes: Int
    let steps: [PlanStep]
}

struct CoachReply: Codable, Hashable {
    var headline: String
    var body: String
    var pills: [DataPill] = []
    var chips: [String] = []
    var plan: CoachPlan? = nil
    /// True when the text came from `CoachRules` / fixed copy, not the model.
    var isTemplate: Bool = false
    /// Demo mode: label the reply "Sample data" (DESIGN_SPEC_v1.1 §7).
    var isSample: Bool = false
    /// True while the model is still streaming this reply (UI: no chips, no numbers yet).
    var isStreaming: Bool = false

    /// Label shown under a sample-data reply.
    static let sampleLabel = Demo.chipText
}

struct CoachMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case user, coach }
    let id: UUID
    let role: Role
    let date: Date
    var reply: CoachReply?
    var text: String?
    /// Metric the user asked about (CoachMark / "Ask about this"), if any.
    var metric: MetricID? = nil

    init(id: UUID = UUID(), role: Role, date: Date = Date(), reply: CoachReply? = nil, text: String? = nil,
         metric: MetricID? = nil) {
        self.id = id
        self.role = role
        self.date = date
        self.reply = reply
        self.text = text
        self.metric = metric
    }

    static func user(_ text: String, about metric: MetricID? = nil) -> CoachMessage {
        CoachMessage(role: .user, text: text, metric: metric)
    }

    static func coach(_ reply: CoachReply) -> CoachMessage {
        CoachMessage(role: .coach, reply: reply)
    }
}

/// One saved conversation (transcripts stay on this iPhone for 30 days).
struct CoachChat: Identifiable, Codable, Hashable {
    let id: UUID
    let started: Date
    var messages: [CoachMessage]

    var lastActivity: Date { messages.last?.date ?? started }
    /// First user question, for the History list.
    var title: String {
        messages.first(where: { $0.role == .user })?.text
            ?? messages.first?.reply?.headline ?? "Chat"
    }
}

struct CoachProfile: Codable, Hashable {
    var goal: String?
    var daysPerWeek: Int?
    var equipment: String?
    var limits: String?

    static let storageKey = "mrh1.coachProfile"

    /// Saved profile (UserDefaults, on device). Empty profile if none.
    static var saved: CoachProfile {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let p = try? JSONDecoder().decode(CoachProfile.self, from: data) else { return CoachProfile() }
            return p
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: storageKey) }
        }
    }

    func save() { CoachProfile.saved = self }
    static func clear() { UserDefaults.standard.removeObject(forKey: storageKey) }

    var isEmpty: Bool { goal == nil && daysPerWeek == nil && equipment == nil && limits == nil }
}

struct CoachNote: Identifiable {
    let id: String
    let headline: String
    let body: String
    let metric: MetricID?
    let chips: [String]
}

struct CoachRuleResult {
    let fired: [String]
    let cap: IntensityCap
    let note: CoachNote?
}

// MARK: - Codable for shared types (tier and metric stored as strings; Theme.swift / Metrics.swift untouched)

extension DataPill: Codable {
    private enum Keys: String, CodingKey { case metric, text, tier }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let raw = try c.decode(String.self, forKey: .metric)
        metric = MetricID(rawValue: raw) ?? .restingHR
        text = try c.decode(String.self, forKey: .text)
        tier = (try c.decodeIfPresent(String.self, forKey: .tier)).flatMap(DataPill.tier(from:))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(metric.rawValue, forKey: .metric)
        try c.encode(text, forKey: .text)
        try c.encodeIfPresent(tier.map(DataPill.tierString), forKey: .tier)
    }

    static func tierString(_ t: StatusTier) -> String {
        switch t {
        case .inRange: return "inRange"
        case .watch: return "watch"
        case .outOfRange: return "outOfRange"
        }
    }

    static func tier(from s: String) -> StatusTier? {
        switch s {
        case "inRange": return .inRange
        case "watch": return .watch
        case "outOfRange": return .outOfRange
        default: return nil
        }
    }
}

extension CoachMessage {
    private enum Keys: String, CodingKey { case id, role, date, reply, text, metric }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(Role.self, forKey: .role)
        date = try c.decode(Date.self, forKey: .date)
        reply = try c.decodeIfPresent(CoachReply.self, forKey: .reply)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        metric = (try c.decodeIfPresent(String.self, forKey: .metric)).flatMap(MetricID.init(rawValue:))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encode(role, forKey: .role)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(reply, forKey: .reply)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(metric?.rawValue, forKey: .metric)
    }
}
