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
    case today, live, body, trends
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .live: "Live"
        case .body: "Body"
        case .trends: "Trends"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .live: "waveform.path.ecg"
        case .body: "square.grid.2x2"
        case .trends: "chart.line.uptrend.xyaxis"
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

    /// Push a route on a tab's stack and switch to it.
    func open(_ route: Route, in tab: AppTab? = nil) {
        let target = tab ?? self.tab
        self.tab = target
        paths[target, default: []].append(route)
    }

    func path(_ tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    /// Screenshot routing: `-tab today|live|body|trends`, `-open recovery|strain|sleep|menu|journal`.
    func applyLaunchArguments(_ args: [String] = ProcessInfo.processInfo.arguments) {
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1].lowercased()
        }
        if let t = value(after: "-tab"), let tab = AppTab(rawValue: t) { self.tab = tab }
        switch value(after: "-open") {
        case "recovery": open(.score(.recovery), in: .today)
        case "strain": open(.score(.strain), in: .today)
        case "sleep": open(.score(.sleep), in: .today)
        case "menu": showMenu = true
        case "journal": showJournal = true
        case "guide": open(.guide)
        case "sources": open(.sources)
        default: break
        }
    }
}
