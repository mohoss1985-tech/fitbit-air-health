import SwiftUI

/// Menu sheet, opened from the round top-left button on every tab (`nav.showMenu = true`).
struct MenuView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MenuList()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        RoundIconButton(systemName: "xmark", label: "Close menu") { dismiss() }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .sources, .dataSources: DataSourcesView()
                    default: GuideView()
                    }
                }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.paper)
    }
}

/// Drop-in round menu button for tab headers.
struct MenuButton: View {
    @Environment(AppNav.self) private var nav
    /// In a navigation toolbar on iOS 26+, the system already draws a glass circle,
    /// so we draw only the glyph there (otherwise you get a double ring).
    var inToolbar = false

    var body: some View {
        if inToolbar, #available(iOS 26, *) {
            Button { nav.showMenu = true } label: {
                Image(systemName: "line.3.horizontal").fontWeight(.medium).foregroundStyle(Theme.ink)
            }
            .accessibilityLabel("Menu")
        } else {
            RoundIconButton(systemName: "line.3.horizontal", label: "Menu") { nav.showMenu = true }
        }
    }
}

/// Menu content: Results guide, Data sources, Notifications, Bluetooth (beta), About.
struct MenuList: View {
    @Environment(LiveStore.self) private var live
    @AppStorage(AppSettings.Key.morning) private var morning = AppSettings.Default.morning
    @AppStorage(AppSettings.Key.drift) private var drift = AppSettings.Default.drift
    @AppStorage(AppSettings.Key.bleEnabled) private var bleOn = AppSettings.Default.bleEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                Card(padding: 0, spacing: 0) {
                    link(.guide, "Results guide", "What each score, result and colour means")
                    divider
                    link(.sources, "Data sources", "What Apple Health has from the last 7 days")
                }

                section("Notifications") {
                    Card(spacing: Space.l) {
                        toggle("Morning summary", "Your recovery and sleep once last night has synced.", isOn: $morning)
                        toggle("Signals outside your usual range", "When 2 or more vitals leave your usual range overnight.", isOn: $drift)
                    }
                }

                section("Live heart rate") {
                    Card(spacing: Space.m) {
                        toggle("Bluetooth live heart rate (beta)",
                               "Reads your band directly while the Live tab is open. Turn on Share heart rate for Fitbit Air in Google Health first.",
                               isOn: $bleOn)
                        if bleOn {
                            HStack {
                                Text("Status").typo(.label).foregroundStyle(Theme.graphite)
                                Spacer()
                                Text(live.bluetoothStatusText).typo(.label).foregroundStyle(Theme.ink)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                section("About") {
                    Card(spacing: Space.m) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("MRH1").typo(.headline).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("Version 1.0").typo(.label).foregroundStyle(Theme.graphite)
                        }
                        Text("Everything is computed on this iPhone. MRH1 reads Apple Health, has no internet code and sends nothing anywhere.")
                            .typo(.body).foregroundStyle(Theme.ink)
                        Text("Works with Fitbit Air via Google Health and Apple Health. Not affiliated with Google.")
                            .typo(.body).foregroundStyle(Theme.graphite)
                        if Demo.isOn {
                            Text("Showing sample data, not your own.")
                                .typo(.body).foregroundStyle(Theme.graphite)
                        }
                    }
                }

                Text("Wellness estimates, not medical advice. See a doctor for symptoms.")
                    .typo(.caption)
                    .foregroundStyle(Theme.graphite)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.section)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: morning) { _, on in if on, !Demo.isOn { Task { await Notifier.requestPermission() } } }
        .onChange(of: drift) { _, on in if on, !Demo.isOn { Task { await Notifier.requestPermission() } } }
        .onChange(of: bleOn) { _, on in live.setBluetooth(enabled: on) }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hair).frame(height: 0.5).padding(.leading, Space.gutter)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(title).padding(.horizontal, Space.xs)
            content()
        }
    }

    private func link(_ route: Route, _ title: String, _ sub: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title).typo(.headline).foregroundStyle(Theme.ink)
                    Text(sub).typo(.caption).foregroundStyle(Theme.graphite)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.graphite2)
                    .accessibilityHidden(true)
            }
            .padding(Space.gutter)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func toggle(_ title: String, _ sub: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).typo(.headline).foregroundStyle(Theme.ink)
                Text(sub).typo(.caption).foregroundStyle(Theme.graphite)
            }
        }
        .tint(Theme.ink)
    }
}
