import SwiftUI
import UIKit

// v1.1 Coach · thread building blocks (DESIGN_SPEC_v1.1 §2, §3, §6; research/v11-03). Owner: agent N.

// MARK: - User bubble

/// Ink fill, paper text, radius 16, padding 12 h / 8 v, max 78 % of the column, no tail. Right aligned,
/// hugging its text.
struct UserBubble: View {
    let text: String

    var body: some View {
        BubbleWidth { UserBubbleCore(text: text) }
            .textSelection(.enabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("You: \(text)")
    }
}

/// Proposes 78 % of the column to the bubble and pins it to the trailing edge.
private struct BubbleWidth: Layout {
    var fraction: CGFloat = 0.78
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let s = subviews.first else { return .zero }
        let maxW = (proposal.width ?? 320) * fraction
        let size = s.sizeThatFits(ProposedViewSize(width: maxW, height: nil))
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let s = subviews.first else { return }
        let size = s.sizeThatFits(ProposedViewSize(width: bounds.width * fraction, height: nil))
        s.place(at: CGPoint(x: bounds.maxX - size.width, y: bounds.minY), proposal: ProposedViewSize(size))
    }
}

private struct UserBubbleCore: View {
    let text: String
    var body: some View {
        Text(text)
            .typo(.body)
            .foregroundStyle(Theme.paper)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
    }
}

// MARK: - Data pill

/// "RHR 58 · normal 54–57" with a status-tier dot; opens the metric when tapped.
struct DataPillView: View {
    let pill: DataPill
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                Circle().fill(pill.tier?.fill ?? Theme.graphite2).frame(width: 6, height: 6)
                Text(pill.text)
                    .typo(.label)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.graphite)
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .strokeBorder(Theme.hair, lineWidth: 0.5))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(pill.tier.map { "\(pill.text), \($0.word)" } ?? pill.text)
        .accessibilityHint("Opens \(pill.metric.info.name)")
    }
}

// MARK: - Suggestion chip

/// Capsule, 36 pt visual / 44 pt hit, `label` type, hair 0.5 stroke, ink text. `dimmed` for chips of
/// earlier turns (graphite text, still tappable).
struct SuggestionChip: View {
    let text: String
    var dimmed: Bool = false
    let action: () -> Void

    init(text: String, dimmed: Bool = false, action: @escaping () -> Void) {
        self.text = text
        self.dimmed = dimmed
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .typo(.label)
                .foregroundStyle(dimmed ? Theme.graphite : Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.l)
                .frame(minHeight: 36)
                .background {
                    Capsule().fill(Theme.card)
                        .overlay(Capsule().strokeBorder(Theme.hair, lineWidth: 0.5))
                }
                .padding(.vertical, Space.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityHint("Sends this as your reply")
    }
}

// MARK: - Thinking

/// The bubble with 3 ember dots pulsing in turn, plus real status text from the tool being called.
/// Reduce Motion: static dots.
struct CoachThinking: View {
    var status: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var glyphWidth: CGFloat = 32

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { ctx in
                let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                ThinkingGlyph(width: glyphWidth, phase: t, animated: !reduceMotion)
            }
            Text(status ?? "Reading your data…")
                .typo(.caption)
                .foregroundStyle(Theme.graphite)
                .contentTransition(.opacity)
                .animation(Motion.crossfade, value: status)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status ?? "Coach is thinking")
    }
}

private struct ThinkingGlyph: View {
    let width: CGFloat
    let phase: TimeInterval
    let animated: Bool

    var body: some View {
        let height = (width * 0.875).rounded()
        let body = CoachBubbleShape.bodyRect(in: CGRect(x: 0, y: 0, width: width, height: height))
        let dot = max(3, body.height * 0.2)
        ZStack(alignment: .topLeading) {
            CoachBubbleShape()
                .stroke(Theme.graphite, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            HStack(spacing: dot * 0.6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Theme.ember).frame(width: dot, height: dot).opacity(opacity(i))
                }
            }
            .frame(width: body.width, height: body.height)
        }
        .frame(width: width, height: height)
    }

    /// Each dot peaks in turn over a 1.2 s cycle (static at 60 % under Reduce Motion).
    private func opacity(_ i: Int) -> Double {
        guard animated else { return 0.6 }
        let cycle = 1.2
        let p = (phase.truncatingRemainder(dividingBy: cycle)) / cycle - Double(i) * 0.2
        let x = p < 0 ? p + 1 : p
        let bump = max(0, 1 - abs(x - 0.2) / 0.2)
        return 0.3 + 0.7 * bump
    }
}

// MARK: - Reply actions

/// thumbs up · thumbs down · copy · retry. Feedback stays on the device.
struct ReplyActions: View {
    @Binding var vote: Bool?
    let copyText: String
    var onRetry: (() -> Void)?
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            icon(vote == true ? "hand.thumbsup.fill" : "hand.thumbsup", "Helpful", selected: vote == true) {
                vote = vote == true ? nil : true
            }
            icon(vote == false ? "hand.thumbsdown.fill" : "hand.thumbsdown", "Not helpful", selected: vote == false) {
                vote = vote == false ? nil : false
            }
            icon(copied ? "checkmark" : "doc.on.doc", copied ? "Copied" : "Copy", selected: false) {
                UIPasteboard.general.string = copyText
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            }
            if let onRetry {
                icon("arrow.clockwise", "Try again", selected: false, action: onRetry)
            }
        }
        .padding(.leading, -Space.m) // optically align the first glyph with the text column
        .sensoryFeedback(.selection, trigger: vote)
    }

    private func icon(_ symbol: String, _ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(selected ? Theme.ink : Theme.graphite)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Coach reply (unboxed)

/// Headline (`.headline`) + body (`.body`) in ink with no bubble, then 1–3 DataPills, an optional PlanCard,
/// and, once the reply has finished, actions and exactly 3 chips.
struct CoachReplyView: View {
    let reply: CoachReply
    let finished: Bool
    let isLatest: Bool
    @Binding var vote: Bool?
    var onChip: (String) -> Void
    var onPill: (DataPill) -> Void
    var onRetry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chips: [String] { Array(reply.chips.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xs) {
                if !reply.headline.isEmpty {
                    Text(reply.headline)
                        .typo(.headline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !reply.body.isEmpty {
                    Text(reply.body)
                        .typo(.body)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.16), value: reply.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Coach: \(reply.headline) \(reply.body)")

            if reply.isSample {
                Text(CoachReply.sampleLabel).typo(.caption).foregroundStyle(Theme.graphite)
            }

            if !reply.pills.isEmpty && !reply.isStreaming {
                CoachFlowLayout(spacing: Space.s, lineSpacing: 0) {
                    ForEach(Array(reply.pills.prefix(3)), id: \.self) { pill in
                        DataPillView(pill: pill) { onPill(pill) }
                    }
                }
                .transition(reduceMotion ? .opacity : .mrhEnter)
            }

            if let plan = reply.plan, !reply.isStreaming {
                PlanCard(plan: plan)
                    .transition(reduceMotion ? .opacity : .mrhEnter)
            }

            if finished {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ReplyActions(vote: $vote, copyText: copyText, onRetry: isLatest ? onRetry : nil)
                    if !chips.isEmpty {
                        CoachFlowLayout(spacing: Space.s, lineSpacing: 0) {
                            ForEach(Array(chips.enumerated()), id: \.element) { i, chip in
                                SuggestionChip(text: chip, dimmed: !isLatest) { onChip(chip) }
                                    .transition(.opacity.animation(.easeOut(duration: 0.16).delay(Double(i) * 0.04)))
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .motionSafe(Motion.enter)
    }

    private var copyText: String {
        [reply.headline, reply.body].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

// MARK: - Starters

/// Starter rows in one card, hair dividers, topic word above a full question.
struct StarterCard: View {
    let starters: [CoachStarter]
    let onTap: (CoachStarter) -> Void

    var body: some View {
        Card(padding: 0, spacing: 0) {
            ForEach(Array(starters.enumerated()), id: \.element) { i, s in
                if i > 0 {
                    Rectangle().fill(Theme.hair).frame(height: 0.5).padding(.leading, Space.gutter)
                }
                Button { onTap(s) } label: {
                    HStack(alignment: .center, spacing: Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.topic).typo(.caption).foregroundStyle(Theme.graphite)
                            Text(s.question)
                                .typo(.headline)
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Space.s)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Theme.graphite2)
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.vertical, Space.m)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(s.question)
                .accessibilityHint("Sends this question to Coach")
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
