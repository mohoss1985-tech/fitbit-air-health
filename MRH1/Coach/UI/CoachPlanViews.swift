import SwiftUI
import UIKit

// v1.1 Coach · PlanCard + PlanRunnerView (DESIGN_SPEC_v1.1 §1 "Workout output", research/v11-03 Screen 3).
// Owner: agent N. No video, nothing written to Apple Health.

enum PlanFormat {
    /// 3:00, 0:45.
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(seconds, 0) / 60, max(seconds, 0) % 60)
    }

    static func spoken(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        if m == 0 { return "\(s) seconds" }
        return s == 0 ? "\(m) minute\(m == 1 ? "" : "s")" : "\(m) minute\(m == 1 ? "" : "s") \(s) seconds"
    }
}

// MARK: - Plan card

/// Inner card (radius 16, paper on paper → card fill): title, length, numbered steps with checkboxes,
/// Start → PlanRunnerView. Always followed by "Stop if you feel pain or dizziness."
struct PlanCard: View {
    let plan: CoachPlan
    @State private var done: Set<Int> = []
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .typo(.headline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(plan.minutes) min, \(plan.steps.count) steps")
                        .typo(.caption)
                        .foregroundStyle(Theme.graphite)
                }
                .padding(.bottom, Space.m)
                .accessibilityElement(children: .combine)

                Rectangle().fill(Theme.hair).frame(height: 0.5)

                ForEach(Array(plan.steps.enumerated()), id: \.offset) { i, step in
                    stepRow(i, step)
                }

                Rectangle().fill(Theme.hair).frame(height: 0.5)

                HStack(spacing: Space.m) {
                    Button { running = true } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: "play.fill").font(.system(size: 12, weight: .medium))
                            Text(done.isEmpty ? "Start" : "Resume").typo(.headline)
                        }
                        .foregroundStyle(Theme.card)
                        .padding(.horizontal, Space.xl)
                        .frame(minHeight: 44)
                        .background(Theme.ink, in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityHint("Opens a step timer")
                    Spacer(minLength: 0)
                    if !done.isEmpty {
                        Text("\(done.count) of \(plan.steps.count) done")
                            .typo(.caption)
                            .foregroundStyle(Theme.graphite)
                            .contentTransition(.numericText())
                    }
                }
                .padding(.top, Space.m)
            }
            .padding(Space.l)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))

            Text("Stop if you feel pain or dizziness.")
                .typo(.caption)
                .foregroundStyle(Theme.graphite)
        }
        .sensoryFeedback(.success, trigger: done.count) { old, new in new > old }
        .fullScreenCover(isPresented: $running) {
            PlanRunnerView(plan: plan, startAt: firstOpenStep) { finished in
                done.formUnion(finished)
            }
        }
    }

    private var firstOpenStep: Int {
        plan.steps.indices.first { !done.contains($0) } ?? 0
    }

    private func stepRow(_ i: Int, _ step: PlanStep) -> some View {
        let isDone = done.contains(i)
        return Button {
            Motion.animate(Motion.press) {
                if isDone { done.remove(i) } else { done.insert(i) }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(isDone ? Theme.ink : Theme.graphite2)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                        Text(step.name)
                            .typo(.body)
                            .foregroundStyle(isDone ? Theme.graphite : Theme.ink)
                            .strikethrough(isDone, color: Theme.graphite2)
                        if let reps = step.reps {
                            Text(reps).typo(.body).foregroundStyle(Theme.graphite)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if !step.cue.isEmpty && !isDone {
                        Text(step.cue)
                            .typo(.caption)
                            .foregroundStyle(Theme.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Space.s)
                if let s = step.seconds {
                    Text(PlanFormat.clock(s)).typo(.label).foregroundStyle(Theme.graphite)
                }
            }
            .padding(.vertical, Space.m)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y(i, step))
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isDone ? "Marks as not done" : "Marks as done")
    }

    private func a11y(_ i: Int, _ step: PlanStep) -> String {
        var parts = ["Step \(i + 1)", step.name]
        if let r = step.reps { parts.append(r.replacingOccurrences(of: "×", with: "") + " reps") }
        if let s = step.seconds { parts.append(PlanFormat.spoken(s)) }
        if !step.cue.isEmpty { parts.append(step.cue) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Plan runner

/// Full-screen step timer: ember TickRing counting down the current step, step name, cue,
/// Back · Pause · Skip. Light haptic at 3-2-1 and on each step change, success at the end.
/// Reps-only steps wait for "Done". The screen stays awake while it runs.
struct PlanRunnerView: View {
    let plan: CoachPlan
    var onClose: (Set<Int>) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var index: Int
    @State private var remaining: Int
    @State private var paused = false
    @State private var finished = false
    @State private var completed: Set<Int> = []
    @State private var tick = 0

    init(plan: CoachPlan, startAt: Int = 0, onClose: @escaping (Set<Int>) -> Void = { _ in }) {
        self.plan = plan
        self.onClose = onClose
        let start = min(max(startAt, 0), max(plan.steps.count - 1, 0))
        _index = State(initialValue: start)
        _remaining = State(initialValue: plan.steps.isEmpty ? 0 : (plan.steps[start].seconds ?? 0))
    }

    private var step: PlanStep? { plan.steps.indices.contains(index) ? plan.steps[index] : nil }
    private var total: Int { step?.seconds ?? 0 }
    private var ringSize: CGFloat { typeSize.isAccessibilitySize ? 200 : 260 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: Space.xl) {
                    if finished { doneView } else if let step { stepView(step) }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            if !finished { controls }
            Text("Stop if you feel pain or dizziness.")
                .typo(.caption)
                .foregroundStyle(Theme.graphite)
                .padding(.top, Space.m)
                .padding(.bottom, Space.s)
        }
        .background(Theme.paper.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .medium), trigger: index)
        .sensoryFeedback(.impact(weight: .light), trigger: tick)
        .sensoryFeedback(.success, trigger: finished) { _, new in new }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true; announce() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task { await run() }
        .accessibilityAction(.magicTap) { if !finished { paused.toggle() } }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack {
            RoundIconButton(systemName: "xmark", label: "End session") { close() }
            Spacer()
            Text(finished ? plan.title : "Step \(index + 1) of \(plan.steps.count)")
                .typo(.label)
                .foregroundStyle(Theme.graphite)
                .lineLimit(1)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
    }

    private func stepView(_ step: PlanStep) -> some View {
        VStack(spacing: Space.xl) {
            TickRing(progress: step.seconds == nil ? 1 : Double(remaining) / Double(max(total, 1)),
                     color: step.seconds == nil ? Theme.graphite2 : Theme.ember,
                     size: ringSize, ticks: 48, animateOnAppear: false,
                     accessibilityName: "Time left") {
                VStack(spacing: Space.xs) {
                    if step.seconds != nil {
                        Text(PlanFormat.clock(remaining))
                            .typo(.display)
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(Motion.crossfade, value: remaining)
                        if paused { Text("Paused").typo(.label).foregroundStyle(Theme.graphite) }
                    } else {
                        Text(step.reps ?? "Your pace")
                            .typo(.metric)
                            .foregroundStyle(Theme.ink)
                        Text("Tap Done when finished").typo(.caption).foregroundStyle(Theme.graphite)
                    }
                }
                .minimumScaleFactor(0.6)
                .padding(Space.xl)
            }
            .accessibilityValue(step.seconds == nil ? (step.reps ?? "") : PlanFormat.spoken(remaining))

            VStack(spacing: Space.s) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(step.name).typo(.title).foregroundStyle(Theme.ink)
                    if let r = step.reps, step.seconds != nil {
                        Text(r).typo(.title).foregroundStyle(Theme.graphite)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                if !step.cue.isEmpty {
                    Text(step.cue)
                        .typo(.body)
                        .foregroundStyle(Theme.graphite)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if plan.steps.indices.contains(index + 1) {
                    Text("Next: \(plan.steps[index + 1].name)")
                        .typo(.caption)
                        .foregroundStyle(Theme.graphite)
                        .padding(.top, Space.s)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var doneView: some View {
        VStack(spacing: Space.l) {
            TickRing(progress: 1, color: Theme.ember, size: ringSize * 0.6, ticks: 48, animateOnAppear: true,
                     accessibilityName: "Session complete") {
                Image(systemName: "checkmark").font(.system(size: 28, weight: .medium)).foregroundStyle(Theme.ink)
            }
            Text("Done.").typo(.title).foregroundStyle(Theme.ink)
            Text("\(completed.count) of \(plan.steps.count) steps done. Not saved to Apple Health.")
                .typo(.body)
                .foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { close() } label: {
                Text("Close")
                    .typo(.headline)
                    .foregroundStyle(Theme.card)
                    .padding(.horizontal, Space.section)
                    .frame(minHeight: 44)
                    .background(Theme.ink, in: Capsule())
            }
            .buttonStyle(PressStyle())
            .padding(.top, Space.s)
        }
        .padding(.top, Space.xl)
    }

    private var controls: some View {
        HStack(spacing: Space.xl) {
            RoundIconButton(systemName: "backward.end.fill", label: "Previous step") { go(to: index - 1, markDone: false) }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.4 : 1)
            Button {
                if step?.seconds == nil { go(to: index + 1, markDone: true) } else { paused.toggle() }
            } label: {
                HStack(spacing: Space.s) {
                    if step?.seconds == nil {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .medium))
                        Text("Done").typo(.headline)
                    } else {
                        Image(systemName: paused ? "play.fill" : "pause.fill").font(.system(size: 15, weight: .medium))
                        Text(paused ? "Resume" : "Pause").typo(.headline)
                    }
                }
                .foregroundStyle(Theme.card)
                .frame(minWidth: 132, minHeight: 56)
                .background(Theme.ink, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(PressStyle())
            RoundIconButton(systemName: "forward.end.fill", label: "Skip step") { go(to: index + 1, markDone: false) }
        }
        .padding(.top, Space.l)
    }

    // MARK: Timer

    private func run() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, !finished, !paused, let step, step.seconds != nil else { continue }
            remaining -= 1
            if remaining > 0 && remaining <= 3 { tick += 1 }
            if remaining <= 0 { go(to: index + 1, markDone: true) }
        }
    }

    private func go(to next: Int, markDone: Bool) {
        if markDone { completed.insert(index) }
        guard next >= 0 else { return }
        if next >= plan.steps.count {
            Motion.animate(Motion.enter) { finished = true }
            UIAccessibility.post(notification: .announcement, argument: "Session done")
            return
        }
        index = next
        remaining = plan.steps[next].seconds ?? 0
        paused = false
        announce()
    }

    private func announce() {
        guard let step else { return }
        let len = step.seconds.map(PlanFormat.spoken) ?? step.reps ?? ""
        UIAccessibility.post(notification: .announcement, argument: "\(step.name), \(len)")
    }

    private func close() {
        onClose(completed)
        dismiss()
    }
}

#Preview("Plan card") {
    ScrollView { PlanCard(plan: CoachDemo.plan).padding(Space.gutter) }
        .background(Theme.paper)
}

#Preview("Runner") {
    PlanRunnerView(plan: CoachDemo.plan)
}
