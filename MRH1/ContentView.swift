import SwiftUI

struct ContentView: View {
    @Environment(HealthStore.self) private var health
    @Environment(LiveStore.self) private var live
    @Environment(AppNav.self) private var nav
    @Environment(\.scenePhase) private var scenePhase

    /// `-onboarding` shows the first-launch screen even when access was already asked (screenshots, demo).
    @State private var forceOnboarding = ProcessInfo.processInfo.arguments.contains("-onboarding")
    @State private var appliedArgs = false

    var body: some View {
        Group {
            if !forceOnboarding && (Demo.isOn || health.hasAsked) {
                MainTabs()
            } else {
                ConnectView { forceOnboarding = false }
            }
        }
        .tint(Theme.ink)
        .background(Theme.paper.ignoresSafeArea())
        .task {
            if !appliedArgs { appliedArgs = true; nav.applyLaunchArguments() }
            if Demo.isOn {
                // Sample data: no HealthKit or notification prompts.
                live.start(health: health)
            } else if health.hasAsked {
                await health.refresh()
                live.start(health: health)
                await Notifier.requestPermission()
            }
        }
        .onChange(of: health.hasAsked) { _, asked in
            guard asked, !Demo.isOn else { return }
            live.start(health: health)
            Task { await Notifier.requestPermission() }
        }
        .onChange(of: health.lastRefresh) { _, _ in live.attach(health: health) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: live.stop()
            case .active where health.hasAsked || Demo.isOn: live.start(health: health)
            default: break
            }
        }
    }
}

// MARK: - Tabs

private struct MainTabs: View {
    @Environment(AppNav.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.tab) {
            tab(.today) { TodayView() }
            tab(.live) { LiveView() }
            tab(.body) { PanelsView() }
            tab(.trends) { TrendsView() }
        }
        // Custom bar floats over content; each tab reserves room for it with a safe-area inset.
        .overlay(alignment: .bottom) { TabBar(selection: $nav.tab) }
        .sheet(isPresented: $nav.showMenu) { MenuView() }
        .sheet(isPresented: $nav.showJournal) { JournalSheet() }
    }

    private func tab<V: View>(_ t: AppTab, @ViewBuilder _ root: () -> V) -> some View {
        NavigationStack(path: nav.path(t)) {
            root().withRoutes()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: TabBar.reservedHeight) }
        .toolbar(.hidden, for: .tabBar)
        .tag(t)
    }
}

/// Round-icon tab bar: ink-filled circle for the selected tab, graphite for the others, no switch animation.
private struct TabBar: View {
    @Binding var selection: AppTab
    static let reservedHeight: CGFloat = 76

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { t in
                let selected = t == selection
                Button {
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) { selection = t }
                } label: {
                    VStack(spacing: Space.xs) {
                        Image(systemName: t.symbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(selected ? Theme.card : Theme.graphite)
                            .frame(width: 44, height: 44)
                            .background { if selected { Circle().fill(Theme.ink) } }
                        Text(t.title)
                            .typo(.micro)
                            .foregroundStyle(selected ? Theme.ink : Theme.graphite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, Space.s)
        .padding(.horizontal, Space.s)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Theme.hair, lineWidth: 0.5))
                .shadow(color: Theme.ink.opacity(0.04), radius: 2, y: 1)
                .shadow(color: Theme.ink.opacity(0.06), radius: 24, y: 8)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.xs)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Routes

extension View {
    /// Every tab can open score details, panels, the guide, data sources, Live and the journal.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .score(let kind): ScoreDetailView(kind: kind)
            case .panels: PanelsView()
            case .panel(let panel): PanelDetailView(panel: panel)
            case .guide: GuideView()
            case .sources, .dataSources: DataSourcesView()
            case .live: LiveView()
            case .menu: MenuList()
            case .journal: JournalSheet()
            }
        }
    }
}

// MARK: - First launch

private struct ConnectView: View {
    @Environment(HealthStore.self) private var health
    var onConnected: () -> Void
    @State private var connecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text("Your Fitbit Air, read calmly.")
                        .typo(.title)
                        .foregroundStyle(Theme.ink)
                    Text("Recovery, sleep, strain and live heart rate from the data your band already shares with Apple Health.")
                        .typo(.body)
                        .foregroundStyle(Theme.graphite)
                }
                .padding(.top, Space.xxl)

                Card {
                    SectionLabel("How your data gets here")
                    DataPath()
                    Text("Google Health sends readings to Apple Health in batches, so new data can take minutes to hours to appear.")
                        .typo(.caption)
                        .foregroundStyle(Theme.graphite)
                }

                VStack(alignment: .leading, spacing: Space.l) {
                    point("iphone", "Computed on this iPhone", "MRH1 only reads Apple Health. It has no internet code and sends nothing anywhere.")
                    point("calendar", "Learns your normal over 14 days", "Scores start as early reads and firm up as your baseline fills in.")
                    point("hand.tap", "One tap to allow", "On the next screen, tap Turn On All, then Allow.")
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    Button {
                        connecting = true
                        Task {
                            await health.requestAccess()
                            connecting = false
                            if health.hasAsked { onConnected() }
                        }
                    } label: {
                        HStack(spacing: Space.s) {
                            if connecting { ProgressView().tint(Theme.card) }
                            Text("Connect Apple Health").typo(.headline)
                        }
                        .foregroundStyle(Theme.card)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.ink, in: Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .disabled(connecting)

                    if let error = health.errorMessage {
                        Text(error).typo(.caption).foregroundStyle(Theme.dangerText)
                    }
                    Text("Works with Fitbit Air via Google Health and Apple Health. Not affiliated with Google. Wellness estimates, not medical advice.")
                        .typo(.caption)
                        .foregroundStyle(Theme.graphite)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.section)
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    private func point(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).typo(.headline).foregroundStyle(Theme.ink)
                Text(text).typo(.body).foregroundStyle(Theme.graphite)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Fitbit Air → Google Health → Apple Health → MRH1, drawn as four stops on one ink line.
private struct DataPath: View {
    private let stops: [(String, String)] = [
        ("Fitbit Air", "Measures"),
        ("Google Health", "Syncs"),
        ("Apple Health", "Stores"),
        ("MRH1", "Reads on device"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                HStack(alignment: .top, spacing: Space.m) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(i == stops.count - 1 ? Theme.ember : Theme.ink)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        if i < stops.count - 1 {
                            Rectangle().fill(Theme.graphite2).frame(width: 1.5).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)
                    HStack(alignment: .firstTextBaseline) {
                        Text(stop.0).typo(.headline).foregroundStyle(Theme.ink)
                        Spacer(minLength: Space.s)
                        Text(stop.1).typo(.caption).foregroundStyle(Theme.graphite)
                    }
                    .padding(.bottom, i < stops.count - 1 ? Space.l : 0)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Data path: Fitbit Air, then Google Health, then Apple Health, then MRH1 on this iPhone.")
    }
}

#Preview {
    ContentView()
        .environment(HealthStore())
        .environment(LiveStore())
        .environment(JournalStore())
        .environment(AppNav())
}
