import SwiftUI
import UIKit

// v1.1 Coach · the conversation screen shared by the Coach tab and CoachSheet. Owner: agent N.
// Reads `CoachEngine` from the environment (injected by integration with `.environment(coach)`).

enum CoachContext: Equatable {
    case tab
    case sheet(MetricID?)

    var metric: MetricID? {
        if case .sheet(let m) = self { return m }
        return nil
    }
}

struct CoachConversation: View {
    let context: CoachContext

    @Environment(CoachEngine.self) private var engine
    @Environment(HealthStore.self) private var health
    @Environment(AppNav.self) private var nav
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft = ""
    @State private var sendTask: Task<Void, Never>?
    @State private var votes: [UUID: Bool] = [:]
    @State private var pillSheet: MetricState?
    @State private var confirmDelete = false
    @State private var chipTaps = 0
    @FocusState private var composerFocused: Bool

    static let footer = "AI coach on this iPhone · can be wrong · wellness, not medical advice."

    private var busy: Bool { engine.isThinking || sendTask != nil }

    private var lastCoachID: UUID? { engine.messages.last(where: { $0.role == .coach })?.id }

    /// Thinking shows until the coach's reply has some text to show.
    private var showThinking: Bool {
        guard engine.isThinking else { return false }
        guard let last = engine.messages.last, last.role == .coach, let r = last.reply else { return true }
        return r.headline.isEmpty && r.body.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        intro
                        ForEach(engine.messages) { m in
                            turn(m).id(m.id)
                        }
                        if showThinking {
                            CoachThinking(status: engine.statusText)
                                .transition(.opacity)
                        }
                        Color.clear.frame(height: 1).id(Self.bottomID)
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.l)
                    .animation(reduceMotion ? Motion.reduced : Motion.enter, value: engine.messages.count)
                    .animation(Motion.crossfade, value: showThinking)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(engine.messages.isEmpty ? .top : .bottom)
                .onChange(of: engine.messages.count) { _, _ in scrollDown(proxy) }
                .onChange(of: engine.messages.last?.reply?.body) { _, _ in scrollDown(proxy, animated: false) }
                .onChange(of: engine.isThinking) { _, _ in scrollDown(proxy) }
            }
            bottomBar
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(item: $pillSheet) { MetricSheet(state: $0) }
        .sensoryFeedback(.selection, trigger: chipTaps)
        .confirmationDialog("Delete coach history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { stop(); engine.deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every Coach chat from this iPhone.")
        }
        .onChange(of: engine.isThinking) { was, now in
            if !was && now { announce("Coach is replying") }
            if was && !now { announce("Coach replied") }
        }
    }

    private static let bottomID = "coach.bottom"

    // MARK: Header

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .center, spacing: Space.m) {
                switch context {
                case .tab:
                    Text("Coach")
                        .typo(.title)
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    if health.isDemo { sampleChip }
                    Spacer(minLength: 0)
                    menu
                case .sheet(let metric):
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coach").typo(.label).foregroundStyle(Theme.graphite)
                        Text(metric.map { "Ask about \($0.info.name.lowercased())" } ?? "Ask Coach")
                            .typo(.headline)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    menu
                    RoundIconButton(systemName: "xmark", label: "Close") { dismiss() }
                }
            }
            if case .rules(let reason) = engine.mode {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Circle().fill(Theme.graphite2).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(reason)
                        .typo(.caption)
                        .foregroundStyle(Theme.graphite)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
    }

    private var sampleChip: some View {
        Text(Demo.chipText)
            .typo(.label)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xs)
            .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(Theme.graphite2, lineWidth: 0.5))
    }

    private var menu: some View {
        Menu {
            Button { stop(); engine.newChat() } label: { Label("New chat", systemImage: "square.and.pencil") }
            if context == .tab {
                Button { nav.showMenu = true } label: { Label("Coach settings", systemImage: "slider.horizontal.3") }
            }
            Divider()
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete coach history", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background {
                    Circle().fill(.ultraThinMaterial)
                        .overlay(Circle().strokeBorder(Theme.hair, lineWidth: 0.5))
                        .shadow(color: Theme.ink.opacity(0.04), radius: 2, y: 1)
                        .shadow(color: Theme.ink.opacity(0.06), radius: 24, y: 8)
                }
                .contentShape(Circle())
        }
        .accessibilityLabel("Coach options")
    }

    // MARK: Intro (greeting + starters)

    @ViewBuilder private var intro: some View {
        switch context {
        case .tab:
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(CoachGreeting.sentence(health))
                        .typo(.title)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if engine.messages.isEmpty {
                        Text("Here’s what I can help with.")
                            .typo(.body)
                            .foregroundStyle(Theme.graphite)
                    }
                }
                if engine.messages.isEmpty {
                    StarterCard(starters: CoachStarterSource.make(health)) { send($0.question, about: $0.metric) }
                }
            }
            .padding(.top, Space.s)
        case .sheet(let metric):
            if engine.messages.isEmpty, let metric {
                StarterCard(starters: CoachStarterSource.about(metric)) { send($0.question, about: metric) }
            }
        }
    }

    // MARK: Turns

    @ViewBuilder private func turn(_ m: CoachMessage) -> some View {
        switch m.role {
        case .user:
            UserBubble(text: m.text ?? "")
        case .coach:
            if let reply = m.reply {
                let latest = m.id == lastCoachID
                CoachReplyView(
                    reply: reply,
                    finished: !reply.isStreaming && !(latest && busy),
                    isLatest: latest,
                    vote: Binding(get: { votes[m.id] }, set: { votes[m.id] = $0 }),
                    onChip: { chipTaps += 1; send($0, about: context.metric) },
                    onPill: { pillSheet = health.state($0.metric) },
                    onRetry: { retry(before: m.id) })
            } else if let text = m.text, !text.isEmpty {
                Text(text)
                    .typo(.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Coach: \(text)")
            }
        }
    }

    // MARK: Composer + footer

    private var bottomBar: some View {
        VStack(spacing: Space.s) {
            CoachComposer(text: $draft,
                          placeholder: placeholder,
                          busy: busy,
                          focused: $composerFocused,
                          onSend: { let t = draft; draft = ""; send(t, about: context.metric) },
                          onStop: stop)
            Text(Self.footer)
                .typo(.caption)
                .foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(Theme.paper)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 0.5) }
    }

    private var placeholder: String {
        if let m = context.metric { return "Ask about \(m.info.name.lowercased())…" }
        return "Ask about your sleep, training…"
    }

    // MARK: Actions

    private func send(_ text: String, about metric: MetricID?) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, sendTask == nil else { return }
        sendTask = Task { @MainActor in
            await engine.send(t, about: metric)
            sendTask = nil
        }
    }

    private func stop() {
        sendTask?.cancel()
        sendTask = nil
    }

    /// Re-asks the user turn that led to the reply `id`.
    private func retry(before id: UUID) {
        guard let i = engine.messages.firstIndex(where: { $0.id == id }),
              let q = engine.messages[..<i].last(where: { $0.role == .user })?.text else { return }
        send(q, about: context.metric)
    }

    private func scrollDown(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard !engine.messages.isEmpty else { return }
        if animated && !reduceMotion {
            withAnimation(Motion.morph) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        } else {
            proxy.scrollTo(Self.bottomID, anchor: .bottom)
        }
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

// MARK: - Composer

/// Card-filled field with a hair stroke, 44 pt minimum, grows to 5 lines then scrolls inside.
/// Send (ink circle, arrow.up) stays pinned trailing and becomes Stop while the coach replies.
/// Dictation goes through the system keyboard mic and never auto-sends.
struct CoachComposer: View {
    @Binding var text: String
    var placeholder: String
    var busy: Bool
    var focused: FocusState<Bool>.Binding
    var onSend: () -> Void
    var onStop: () -> Void

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(alignment: .bottom, spacing: Space.s) {
            TextField(placeholder, text: $text, axis: .vertical)
                .typo(.body)
                .foregroundStyle(Theme.ink)
                .tint(Theme.ember)
                .lineLimit(1...5)
                .focused(focused)
                .submitLabel(.send)
                .padding(.leading, Space.l)
                .padding(.vertical, Space.m)
                .accessibilityLabel("Message Coach")

            Button(action: busy ? onStop : onSend) {
                Image(systemName: busy ? "stop.fill" : "arrow.up")
                    .font(.system(size: busy ? 12 : 15, weight: .semibold))
                    .foregroundStyle(Theme.card)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(busy || canSend ? Theme.ink : Theme.graphite2))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .disabled(!busy && !canSend)
            .accessibilityLabel(busy ? "Stop reply" : "Send")
            .padding(.trailing, Space.xs)
        }
        .frame(minHeight: 44)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Theme.hair, lineWidth: 0.5))
        }
        .animation(Motion.press, value: busy)
    }
}
