import SwiftUI

// v1.1 Coach · UI entry points (DESIGN_SPEC_v1.1 §2–§6). Owner: agent N. Names FIXED.
// Building blocks live in Coach/UI/: CoachThread (bubbles, pills, chips, thinking), CoachComposer,
// CoachPlanViews (PlanCard, PlanRunnerView), CoachSupport (greeting, starters, layout, demo data).

// MARK: - Signature shape

/// The coach's one symbol (§3): a rounded speech bubble, radius ~35 % of the body height,
/// with a short tail at the bottom left. The body takes the top 80 % of the rect, the tail the rest.
struct CoachBubbleShape: Shape {
    /// Share of the height used by the body (the tail hangs below it).
    var bodyRatio: CGFloat = 0.8

    /// The body rect inside `rect` (for centring the dot).
    static func bodyRect(in rect: CGRect, bodyRatio: CGFloat = 0.8) -> CGRect {
        CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * bodyRatio)
    }

    func path(in rect: CGRect) -> Path {
        let b = Self.bodyRect(in: rect, bodyRatio: bodyRatio)
        let r = min(b.height * 0.35, min(b.width, b.height) / 2)
        let tailStart = b.minX + max(r, b.width * 0.24)        // where the tail leaves the bottom edge
        let tailEnd = b.minX + b.width * 0.46                  // where it rejoins
        let tip = CGPoint(x: b.minX + b.width * 0.16, y: rect.maxY)

        var p = Path()
        p.move(to: CGPoint(x: b.minX + r, y: b.minY))
        p.addLine(to: CGPoint(x: b.maxX - r, y: b.minY))
        p.addArc(tangent1End: CGPoint(x: b.maxX, y: b.minY), tangent2End: CGPoint(x: b.maxX, y: b.minY + r), radius: r)
        p.addLine(to: CGPoint(x: b.maxX, y: b.maxY - r))
        p.addArc(tangent1End: CGPoint(x: b.maxX, y: b.maxY), tangent2End: CGPoint(x: b.maxX - r, y: b.maxY), radius: r)
        p.addLine(to: CGPoint(x: tailEnd, y: b.maxY))
        // Short tail: a soft curve down to the tip, then back up to the bottom edge.
        p.addQuadCurve(to: tip, control: CGPoint(x: b.minX + b.width * 0.30, y: b.maxY + (rect.maxY - b.maxY) * 0.35))
        p.addQuadCurve(to: CGPoint(x: tailStart, y: b.maxY), control: CGPoint(x: tip.x + b.width * 0.06, y: b.maxY + (rect.maxY - b.maxY) * 0.2))
        p.addLine(to: CGPoint(x: b.minX + r, y: b.maxY))
        p.addArc(tangent1End: CGPoint(x: b.minX, y: b.maxY), tangent2End: CGPoint(x: b.minX, y: b.maxY - r), radius: r)
        p.addLine(to: CGPoint(x: b.minX, y: b.minY + r))
        p.addArc(tangent1End: CGPoint(x: b.minX, y: b.minY), tangent2End: CGPoint(x: b.minX + r, y: b.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

/// Bubble outline + ember dot, drawn at any size. Used by CoachMark, the tab icon and CoachThinking.
struct CoachGlyph: View {
    var width: CGFloat = 16
    var stroke: Color = Theme.graphite2
    var lineWidth: CGFloat = 1.25
    var dotOpacity: Double = 0.6

    private var height: CGFloat { (width * 0.875).rounded() }

    var body: some View {
        let body = CoachBubbleShape.bodyRect(in: CGRect(x: 0, y: 0, width: width, height: height))
        let dot = max(3, body.height * 0.34)
        ZStack(alignment: .topLeading) {
            CoachBubbleShape()
                .stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(Theme.ember.opacity(dotOpacity))
                .frame(width: dot, height: dot)
                .offset(x: body.midX - dot / 2, y: body.midY - dot / 2)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - CoachMark

/// Small coach entry on data cards (§3): 16 pt bubble, graphite2 stroke, ember dot at 60 %,
/// 44 pt hit area. Pressed, the stroke turns ink. Tap → `nav.openCoach(about:)` (sheet about the metric).
struct CoachMark: View {
    @Environment(AppNav.self) private var nav
    let metric: MetricID?
    /// VoiceOver name when there is no MetricID (e.g. "Recovery", "Strain").
    var name: String? = nil

    init(metric: MetricID?, name: String? = nil) {
        self.metric = metric
        self.name = name
    }

    private var spokenName: String? { name ?? metric?.info.name }

    var body: some View {
        Button { nav.openCoach(about: metric) } label: { EmptyView() }
            .buttonStyle(CoachMarkStyle())
            .accessibilityLabel(spokenName.map { "Ask Coach about \($0)" } ?? "Ask Coach")
            .accessibilityHint("Opens a chat about this number")
    }
}

private struct CoachMarkStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        CoachGlyph(width: 16, stroke: configuration.isPressed ? Theme.ink : Theme.graphite2,
                   lineWidth: 1.25, dotOpacity: configuration.isPressed ? 1 : 0.6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? Motion.pressScale : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

// MARK: - Tab icon

/// The bubble at tab size for the tab bar. Follows the bar's convention: on the ink-filled selected
/// circle the stroke is `Theme.card` with a full ember dot; unselected it is graphite with the dot at 60 %.
/// Pass `stroke` to override (e.g. `Theme.ink` on a plain background, as §3 describes).
struct CoachTabIcon: View {
    let selected: Bool
    var stroke: Color? = nil

    init(selected: Bool, stroke: Color? = nil) {
        self.selected = selected
        self.stroke = stroke
    }

    var body: some View {
        CoachGlyph(width: 20, stroke: stroke ?? (selected ? Theme.card : Theme.graphite),
                   lineWidth: 1.6, dotOpacity: selected ? 1 : 0.6)
            .offset(y: 1) // optical centring: the tail makes the glyph look high
    }
}

// MARK: - Coach tab

/// Coach tab root: header (title + menu), greeting with today's numbers, 4 starter rows,
/// the conversation, the composer and the footer caption.
struct CoachView: View {
    var body: some View {
        CoachConversation(context: .tab)
            .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Coach sheet

/// The same chat, opened over any screen from a CoachMark or "Ask about this", seeded with `metric`.
struct CoachSheet: View {
    let metric: MetricID?
    @Environment(CoachEngine.self) private var engine
    @Environment(AppNav.self) private var nav
    @State private var seeded = false
    /// v1.3: question from `nav.coachPrompt` (Coach note chip), sent once right after seeding.
    @State private var prompt: String?

    init(metric: MetricID?) { self.metric = metric }

    var body: some View {
        CoachConversation(context: .sheet(metric), prompt: prompt)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.paper)
            .onAppear {
                guard !seeded else { return }
                seeded = true
                let q = nav.takeCoachPrompt()
                // With a question to send, skip the instant opener: the reply answers the question.
                engine.start(about: metric, opener: q == nil)
                prompt = q
            }
    }
}

// MARK: - Today note

/// Rule-based proactive note on Today (§4.4): "Coach" label, headline, body capped at 40 words in total,
/// up to 2 chips. Collapsible to its headline. Tap → `nav.openCoach(about:)`.
struct CoachNoteCard: View {
    let note: CoachNote
    @Environment(AppNav.self) private var nav
    @AppStorage("mrh1.coach.collapsedNote") private var collapsedID = ""

    init(note: CoachNote) { self.note = note }

    private var collapsed: Bool { collapsedID == note.id }

    /// Headline + body together never exceed 40 words; the body is trimmed with "…".
    private var bodyText: String {
        let budget = max(0, 40 - note.headline.split(whereSeparator: \.isWhitespace).count)
        let words = note.body.split(whereSeparator: \.isWhitespace)
        guard words.count > budget else { return note.body }
        guard budget > 0 else { return "" }
        return words.prefix(budget).joined(separator: " ").trimmingCharacters(in: .punctuationCharacters) + "…"
    }

    var body: some View {
        Card(spacing: Space.s) {
            HStack(alignment: .center, spacing: Space.s) {
                CoachGlyph(width: 16, stroke: Theme.graphite, lineWidth: 1.25, dotOpacity: 1)
                Text("Coach").typo(.label).foregroundStyle(Theme.graphite)
                Spacer(minLength: Space.s)
                Button {
                    Motion.animate(Motion.morph) { collapsedID = collapsed ? "" : note.id }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.graphite)
                        .rotationEffect(.degrees(collapsed ? 0 : 180))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .padding(.vertical, -Space.m)
                .padding(.trailing, -Space.m)
                .accessibilityLabel(collapsed ? "Show coach note" : "Hide coach note")
            }

            Button { nav.openCoach(about: note.metric) } label: {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(note.headline)
                        .typo(.headline)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !collapsed && !bodyText.isEmpty {
                        Text(bodyText)
                            .typo(.body)
                            .foregroundStyle(Theme.graphite)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coach: \(note.headline). \(collapsed ? "" : bodyText)")
            .accessibilityHint("Opens Coach about this")

            if !collapsed && !note.chips.isEmpty {
                CoachFlowLayout(spacing: Space.s) {
                    ForEach(Array(note.chips.prefix(2)), id: \.self) { chip in
                        // v1.3: the chip opens Coach and sends its question.
                        SuggestionChip(text: chip) { nav.openCoach(about: note.metric, asking: chip) }
                    }
                }
                .padding(.top, Space.xs)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Previews

#Preview("Coach tab · light") {
    CoachPreviewHost { CoachView() }
}

#Preview("Coach tab · dark") {
    CoachPreviewHost { CoachView() }.preferredColorScheme(.dark)
}

#Preview("Coach sheet") {
    CoachPreviewHost { CoachSheet(metric: .restingHR) }
}

#Preview("Marks and note") {
    CoachPreviewHost {
        VStack(alignment: .leading, spacing: Space.xl) {
            HStack(spacing: Space.l) {
                CoachMark(metric: .restingHR)
                CoachTabIcon(selected: false)
                CoachTabIcon(selected: true).frame(width: 44, height: 44).background(Circle().fill(Theme.ink))
                CoachGlyph(width: 64, stroke: Theme.ink, lineWidth: 3, dotOpacity: 1)
            }
            CoachNoteCard(note: CoachDemo.note)
        }
        .padding(Space.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.paper)
    }
}
