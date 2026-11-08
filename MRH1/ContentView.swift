import SwiftUI

struct ContentView: View {
    @Environment(HealthStore.self) private var health
    @Environment(LiveStore.self) private var live
    @Environment(AppNav.self) private var nav
    @Environment(JournalStore.self) private var journal
    @Environment(CoachEngine.self) private var coach
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
                configureCoach()
            } else if health.hasAsked {
                await health.refresh()
                configureCoach()
                live.start(health: health)
                await Notifier.requestPermission()
            }
            #if DEBUG
            // v1.3: `-runChecks` runs the Coach B1–B5 self-test once and prints "CHECK …" lines.
            if ProcessInfo.processInfo.arguments.contains("-runChecks") { runCoachChecks() }
            #endif
        }
        .onChange(of: health.hasAsked) { _, asked in
            guard asked, !Demo.isOn else { return }
            live.start(health: health)
            Task { await Notifier.requestPermission() }
        }
        .onChange(of: health.lastRefresh) { _, _ in live.attach(health: health); configureCoach() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: live.stop()
            case .active where health.hasAsked || Demo.isOn:
                live.start(health: health)
                // Coming back (e.g. from Google Health after Sync now): re-read Apple Health, then
                // again at 30 s and 90 s, because Google Health writes a minute or so after it syncs.
                guard !Demo.isOn else { break }
                Task {
                    let before = health.latestSampleDate
                    for wait in [0, 30, 60] {
                        try? await Task.sleep(for: .seconds(wait))
                        await health.refresh()
                        if health.latestSampleDate != before { return }
                    }
                }
            default: break
            }
        }
    }

    /// Hands the coach the stores it reads (tools + rules). Safe to call again after each refresh.
    #if DEBUG
    private func runCoachChecks() {
        let failures = CoachRulesChecks.run(health: health, journal: journal) { print("CHECK \($0)") }
        print(failures.isEmpty ? "CHECK ALL PASSED" : "CHECK \(failures.count) FAILED")
    }
    #endif

    private func configureCoach() {
        coach.configure(health: health, journal: journal)
    }
}

// MARK: - Tabs

private struct MainTabs: View {
    @Environment(AppNav.self) private var nav
    @AppStorage(CoachPrefs.Key.enabled) private var coachOn = CoachPrefs.defaultEnabled
    @State private var keyboardUp = false

    /// Coach off hides the 5th tab: the exact v1.0 four-tab bar.
    private var tabs: [AppTab] { AppTab.allCases.filter { coachOn || $0 != .coach } }

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.tab) {
            tab(.today) { TodayView() }
            tab(.live) { LiveView() }
            tab(.body) { PanelsView() }
            tab(.trends) { TrendsView() }
            if coachOn { tab(.coach) { CoachTabRoot() } }
        }
        // Custom bar floats over content; each tab reserves room for it with a safe-area inset.
        // The bar hides while the keyboard is up (Coach composer), so the composer sits right on the keyboard.
        .overlay(alignment: .bottom) {
            if !keyboardUp { TabBar(selection: $nav.tab, tabs: tabs) { nav.reselect($0) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .sheet(isPresented: $nav.showMenu) { MenuView() }
        .sheet(isPresented: $nav.showJournal) { JournalSheet() }
        // CoachMark / "Ask about this" from any tab: the chat as a large sheet, seeded with the metric.
        .sheet(isPresented: Binding(get: { nav.showCoachSheet && coachOn },
                                    set: { nav.showCoachSheet = $0 })) {
            CoachSheet(metric: nav.coachMetric)
        }
        .onChange(of: coachOn, initial: true) { _, on in
            guard !on else { return }
            if nav.tab == .coach { nav.tab = .today }
            nav.showCoachSheet = false
        }
    }

    private func tab<V: View>(_ t: AppTab, @ViewBuilder _ root: () -> V) -> some View {
        NavigationStack(path: nav.path(t)) {
            // Inset on the root view itself: on iOS 27 an inset on the NavigationStack no longer reaches
            // the scroll views, so the last rows (and the Coach composer) sat under the floating tab bar.
            root().withRoutes()
                .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: keyboardUp ? 0 : TabBar.reservedHeight) }
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(t)
    }
}

/// Round-icon tab bar: ink-filled circle for the selected tab, graphite for the others, no switch animation.
private struct TabBar: View {
    @Binding var selection: AppTab
    var tabs: [AppTab] = AppTab.allCases
    /// Tap on the tab that is already selected.
    var onReselect: (AppTab) -> Void = { _ in }
    static let reservedHeight: CGFloat = 76

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { t in
                let selected = t == selection
                Button {
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    if t == selection { onReselect(t) } else { withTransaction(tx) { selection = t } }
                } label: {
                    VStack(spacing: Space.xs) {
                        Group {
                            if t == .coach {
                                // The coach's own speech-bubble symbol, never an SF Symbol (DESIGN_SPEC_v1.1 §3).
                                CoachTabIcon(selected: selected)
                            } else {
                                Image(systemName: t.symbol)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(selected ? Theme.card : Theme.graphite)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background { if selected { Circle().fill(Theme.ink) } }
                        Text(t.title)
                            .typo(.micro)
                            .foregroundStyle(selected ? Theme.ink : Theme.graphite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                // Labels stop growing at XXL so 5 tabs always fit; long-press shows them large.
                .accessibilityShowsLargeContentViewer {
                    if t == .coach { CoachTabIcon(selected: false, stroke: Theme.ink) } else { Image(systemName: t.symbol) }
                    Text(t.title)
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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

// MARK: - Coach integration (v1.1)

/// Coach tab root: the one-time "What Coach can see" screen, then the coach.
private struct CoachTabRoot: View {
    @AppStorage(CoachPrefs.Key.onboarded) private var onboarded = false

    var body: some View {
        if onboarded {
            CoachView()
        } else {
            CoachIntroView { onboarded = true }
        }
    }
}

/// Shown once, on the first open of the Coach tab (DESIGN_SPEC_v1.1 §4.6): what the coach reads,
/// that it runs on this iPhone, the intended purpose, and an 18+ confirmation.
private struct CoachIntroView: View {
    @Environment(AppNav.self) private var nav
    let onStart: () -> Void
    @State private var adult = false

    private let sees: [(String, String)] = [
        ("heart", "Heart rate and resting heart rate"),
        ("bed.double", "Sleep times and stages"),
        ("lungs", "Breathing rate and blood oxygen"),
        ("figure.walk", "Steps, active energy and workouts"),
        ("gauge.with.dots.needle.33percent", "Your Recovery, Strain and Sleep scores"),
        ("tag", "Your journal tags"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                VStack(alignment: .leading, spacing: Space.m) {
                    CoachGlyph(width: 28, stroke: Theme.ink, lineWidth: 1.8, dotOpacity: 1)
                    Text("What Coach can see")
                        .typo(.title)
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Coach explains your own numbers in a few words and suggests what to do next.")
                        .typo(.body)
                        .foregroundStyle(Theme.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Space.xl)

                Card(spacing: Space.l) {
                    SectionLabel("From Apple Health and MRH1")
                    ForEach(sees, id: \.1) { item in
                        HStack(spacing: Space.m) {
                            Image(systemName: item.0)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text(item.1).typo(.body).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Space.l) {
                    point("iphone", "Processed on this iPhone",
                          "Coach runs on this iPhone. Nothing is sent anywhere, and MRH1 has no internet code.")
                    point("clock.arrow.circlepath", "Chats stay 30 days",
                          "Kept on this iPhone only. Delete them any time in Menu.")
                    point("stethoscope", "Wellness, not medical advice",
                          "Coach gives general wellness and fitness suggestions based on your own Apple Health data. It is not a medical device and does not diagnose, treat or prevent any condition. Check with a doctor before making health decisions.")
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    Toggle(isOn: $adult) {
                        Text("I am 18 or older").typo(.headline).foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.ink)
                    .frame(minHeight: 44)

                    Button(action: onStart) {
                        Text("Start Coach")
                            .typo(.headline)
                            .foregroundStyle(Theme.card)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.ink.opacity(adult ? 1 : 0.3), in: Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!adult)
                    .accessibilityHint(adult ? "" : "Confirm you are 18 or older first")

                    Button { nav.tab = .today } label: {
                        Text("Not now")
                            .typo(.label)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())

                    Text("You can turn Coach off in Menu. Off, MRH1 works exactly as before.")
                        .typo(.caption)
                        .foregroundStyle(Theme.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.section)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A CoachMark that takes no more layout room than its 16 pt glyph (the 44 pt hit area overhangs),
/// so cards and rows keep their v1.0 size. Hidden while the coach is off.
struct CoachMarkSlot: View {
    let metric: MetricID?
    var name: String? = nil
    @AppStorage(CoachPrefs.Key.enabled) private var coachOn = CoachPrefs.defaultEnabled

    var body: some View {
        if coachOn {
            CoachMark(metric: metric, name: name)
                .contentShape(Rectangle())
                .padding(-14)
                .frame(width: 16, height: 16)
        }
    }
}

extension View {
    /// VoiceOver action "Ask Coach" for rows/cards that merge their children into one element
    /// (the visible CoachMark inside them is then not reachable on its own).
    func coachAccessibilityAction(_ action: @escaping () -> Void) -> some View {
        modifier(CoachAXAction(action: action))
    }
}

private struct CoachAXAction: ViewModifier {
    let action: () -> Void
    @AppStorage(CoachPrefs.Key.enabled) private var coachOn = CoachPrefs.defaultEnabled

    func body(content: Content) -> some View {
        if coachOn {
            content.accessibilityAction(named: Text("Ask Coach"), action)
        } else {
            content
        }
    }
}

/// "Ask about this" row at the foot of ScoreDetail and MetricSheet (DESIGN_SPEC_v1.1 §4.3).
/// Hidden while the coach is off.
struct AskCoachRow: View {
    let name: String
    let action: () -> Void
    @AppStorage(CoachPrefs.Key.enabled) private var coachOn = CoachPrefs.defaultEnabled

    var body: some View {
        if coachOn {
            Button(action: action) {
                HStack(spacing: Space.m) {
                    CoachGlyph(width: 18, stroke: Theme.ink, lineWidth: 1.4, dotOpacity: 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ask about this").typo(.headline).foregroundStyle(Theme.ink)
                        Text("Coach explains your \(name.lowercased()) on this iPhone")
                            .typo(.caption).foregroundStyle(Theme.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: Space.s)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.graphite2)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.m)
                .frame(minHeight: 56)
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Theme.hair, lineWidth: 0.5))
                .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
            .buttonStyle(PressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ask Coach about \(name)")
            .accessibilityAddTraits(.isButton)
        }
    }
}

#Preview {
    ContentView()
        .environment(HealthStore())
        .environment(LiveStore())
        .environment(JournalStore())
        .environment(AppNav())
        .environment(CoachEngine())
}
