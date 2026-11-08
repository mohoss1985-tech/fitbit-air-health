import SwiftUI
import Observation

/// Push destinations inside each tab's NavigationStack (handled by `View.withRoutes()` in ContentView).
enum Route: Hashable {
    case score(ScoreKind)
    case panels
    case panel(Panel)
    case guide
    case sources
    /// Same screen as `.sources` (name used in the v1 contract).
    case dataSources
    case live
    /// Menu pushed as a page. The usual way is `AppNav.showMenu = true` (sheet).
    case menu
    case journal
}

enum ScoreKind: String, Hashable {
    case recovery, strain, sleep
}

/// App tabs, in bar order.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case today, live, body, trends, coach
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .live: "Live"
        case .body: "Body"
        case .trends: "Trends"
        case .coach: "Coach"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .live: "waveform.path.ecg"
        case .body: "square.grid.2x2"
        case .trends: "chart.line.uptrend.xyaxis"
        case .coach: "bubble.left" // tab bar draws CoachBubbleShape instead (agent O)
        }
    }
}

/// App-wide navigation state, injected with `.environment(nav)`.
/// Tab screens open the menu with `nav.showMenu = true` (or `MenuButton()`),
/// the journal with `nav.showJournal = true`, and switch tabs with `nav.tab = .body`.
@Observable @MainActor final class AppNav {
    var tab: AppTab = .today
    var showMenu = false
    var showJournal = false
    var paths: [AppTab: [Route]] = [:]
    /// Bumped when the already-selected tab is tapped again on its root screen: that tab scrolls to the top.
    var scrollTopTick: [AppTab: Int] = [:]

    /// Tapping the current tab again (standard iOS): first back to the tab's start screen, then to the top.
    func reselect(_ tab: AppTab) {
        if !(paths[tab] ?? []).isEmpty { paths[tab] = [] } else { scrollTopTick[tab, default: 0] += 1 }
    }
    /// v1.1 Coach: metric the coach sheet was opened about (CoachMark / "Ask about this").
    var coachMetric: MetricID? = nil
    var showCoachSheet = false

    /// Opens the coach about a metric (sheet over the current screen) or, with nil, the Coach tab.
    /// Does nothing while the coach is switched off in Menu (v1.0 behaviour).
    func openCoach(about metric: MetricID?) {
        guard CoachPrefs.isEnabled else { return }
        if let metric { coachMetric = metric; showCoachSheet = true } else { tab = .coach }
    }

    /// v1.3: question to send once when the Coach opens (Coach note chips). The Coach tab / sheet sends it
    /// when it appears, then clears it (`takeCoachPrompt()`).
    var coachPrompt: String? = nil

    /// Opens the coach like `openCoach(about:)` and sends `question` once it is on screen.
    /// Does nothing while the coach is switched off in Menu (v1.0 behaviour).
    func openCoach(about metric: MetricID?, asking question: String?) {
        guard CoachPrefs.isEnabled else { return }
        let q = question?.trimmingCharacters(in: .whitespacesAndNewlines)
        coachPrompt = (q?.isEmpty ?? true) ? nil : q
        openCoach(about: metric)
    }

    /// Returns the pending `coachPrompt` and clears it (nil while the coach is off).
    func takeCoachPrompt() -> String? {
        defer { coachPrompt = nil }
        return CoachPrefs.isEnabled ? coachPrompt : nil
    }

    /// Always opens the coach as a sheet over the current screen, also without a metric
    /// (e.g. "Ask about this" on the Recovery and Strain details, which have no MetricID).
    func openCoachSheet(about metric: MetricID?) {
        guard CoachPrefs.isEnabled else { return }
        coachMetric = metric
        showCoachSheet = true
    }

    /// Push a route on a tab's stack and switch to it.
    func open(_ route: Route, in tab: AppTab? = nil) {
        let target = tab ?? self.tab
        self.tab = target
        paths[target, default: []].append(route)
    }

    func path(_ tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    /// Screenshot routing: `-tab today|live|body|trends|coach`, `-open recovery|strain|sleep|menu|journal|guide|sources|coach`.
    /// `-coachSkipIntro` skips the one-time "What Coach can see" screen (marks it seen).
    func applyLaunchArguments(_ args: [String] = ProcessInfo.processInfo.arguments) {
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1].lowercased()
        }
        if args.contains("-coachSkipIntro") { UserDefaults.standard.set(true, forKey: CoachPrefs.Key.onboarded) }
        if let t = value(after: "-tab"), let tab = AppTab(rawValue: t), tab != .coach || CoachPrefs.isEnabled { self.tab = tab }
        switch value(after: "-open") {
        case "recovery": open(.score(.recovery), in: .today)
        case "strain": open(.score(.strain), in: .today)
        case "sleep": open(.score(.sleep), in: .today)
        case "menu": showMenu = true
        case "journal": showJournal = true
        case "guide": open(.guide)
        case "sources": open(.sources)
        case "coach": openCoachSheet(about: nil)
        default: break
        }
    }
}

// MARK: - Coach settings (v1.1)

/// Coach preferences in UserDefaults. Bind in views with `@AppStorage(CoachPrefs.Key.enabled)`.
/// Coach off = the exact v1.0 app: no tab, no CoachMarks, no "Ask about this" rows, no Today note.
enum CoachPrefs {
    enum Key {
        /// Coach on/off (Bool, default true).
        static let enabled = "coach.enabled"
        /// Proactive notes on Today (`Proactive.rawValue`, default `.daily`).
        static let proactive = "coach.proactive"
        /// Reply style (`Style.rawValue`, default `.direct`).
        static let style = "coach.style"
        /// "What Coach can see" + 18+ confirm was accepted (Bool, default false).
        static let onboarded = "coach.onboarded"
    }

    enum Proactive: String, CaseIterable, Identifiable {
        case off, important, daily, every
        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: "Off"
            case .important: "Important only"
            case .daily: "Daily"
            case .every: "Every moment"
            }
        }
        var detail: String {
            switch self {
            case .off: "No coach notes on Today."
            case .important: "Only when a signal is outside your usual range."
            case .daily: "One note a day on Today."
            case .every: "Up to 3 a day: morning, after a workout, evening."
            }
        }
    }

    enum Style: String, CaseIterable, Identifiable {
        case direct, supportive, numbers
        var id: String { rawValue }
        var title: String {
            switch self {
            case .direct: "Direct"
            case .supportive: "Supportive"
            case .numbers: "Numbers only"
            }
        }
    }

    static let defaultEnabled = true
    static let defaultProactive = Proactive.daily
    static let defaultStyle = Style.direct

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Key.enabled) as? Bool ?? defaultEnabled
    }
    static var proactive: Proactive {
        UserDefaults.standard.string(forKey: Key.proactive).flatMap(Proactive.init(rawValue:)) ?? defaultProactive
    }
    static var style: Style {
        UserDefaults.standard.string(forKey: Key.style).flatMap(Style.init(rawValue:)) ?? defaultStyle
    }
}


// MARK: - Tap the tab again → top

extension View {
    /// Scrolls this tab's root scroll view to the top when its tab is tapped again.
    func scrollsToTopOnReselect(_ tab: AppTab) -> some View { modifier(ReselectScrollTop(tab: tab)) }
}

private struct ReselectScrollTop: ViewModifier {
    let tab: AppTab
    func body(content: Content) -> some View {
        if #available(iOS 18, *) { content.modifier(ReselectScrollTop18(tab: tab)) } else { content }
    }
}

@available(iOS 18, *)
private struct ReselectScrollTop18: ViewModifier {
    let tab: AppTab
    @Environment(AppNav.self) private var nav
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onChange(of: nav.scrollTopTick[tab]) { _, _ in
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { position.scrollTo(edge: .top) }
            }
    }
}
