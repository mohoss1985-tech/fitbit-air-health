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

/// Menu content: Results guide, Data sources, Coach, Notifications, Bluetooth (beta), About.
struct MenuList: View {
    @Environment(LiveStore.self) private var live
    @Environment(CoachEngine.self) private var coach
    @AppStorage(CoachPrefs.Key.enabled) private var coachOn = CoachPrefs.defaultEnabled
    @AppStorage(CoachPrefs.Key.proactive) private var proactive = CoachPrefs.defaultProactive.rawValue
    @AppStorage(CoachPrefs.Key.style) private var style = CoachPrefs.defaultStyle.rawValue
    @State private var confirmDelete = false
    @State private var deleted = false
    @Environment(\.dynamicTypeSize) private var typeSize
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

                section("Coach") {
                    Card(spacing: Space.l) {
                        toggle("Coach", "Explains your numbers and suggests what to do next. Runs on this iPhone. Off, MRH1 works exactly as before.",
                               isOn: $coachOn)
                        if coachOn {
                            pickerRow("Proactive notes", CoachPrefs.Proactive(rawValue: proactive)?.detail ?? "",
                                      selection: $proactive,
                                      options: CoachPrefs.Proactive.allCases.map { ($0.rawValue, $0.title) })
                            pickerRow("Style", styleDetail, selection: $style,
                                      options: CoachPrefs.Style.allCases.map { ($0.rawValue, $0.title) })
                            Button { confirmDelete = true } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: Space.xs) {
                                        Text("Delete coach history").typo(.headline).foregroundStyle(Theme.dangerText)
                                        Text(deleted ? "Deleted from this iPhone." : "Chats are kept on this iPhone for 30 days.")
                                            .typo(.caption).foregroundStyle(Theme.graphite)
                                    }
                                    Spacer()
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressStyle())
                            .confirmationDialog("Delete all coach chats from this iPhone?", isPresented: $confirmDelete,
                                                titleVisibility: .visible) {
                                Button("Delete coach history", role: .destructive) {
                                    coach.deleteAll()
                                    deleted = true
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }
                }

                section("Notifications") {
                    Card(spacing: Space.l) {
                        toggle("Morning summary", "Your recovery and sleep once last night has synced.", isOn: $morning)
                        toggle("Signals outside your usual range", "When 2 or more vitals leave your usual range overnight.", isOn: $drift)
                    }
                }

                // Hidden until Google Health offers "Share heart rate" on iPhone: the band has the
                // standard HR service but stays silent without it (tested 2026-11-05). Shown only
                // to anyone who already turned it on, so they can turn it off.
                if bleOn {
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

                }

                section("About") {
                    Card(spacing: Space.m) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("MRH1").typo(.headline).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("Version 1.1").typo(.label).foregroundStyle(Theme.graphite)
                        }
                        Text("Everything, including the coach, runs on this iPhone. No internet code. MRH1 reads Apple Health and sends nothing anywhere.")
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

    private var styleDetail: String {
        switch CoachPrefs.Style(rawValue: style) ?? CoachPrefs.defaultStyle {
        case .direct: "Short and to the point."
        case .supportive: "Warmer wording, same facts."
        case .numbers: "Plain data sentences, no suggestions."
        }
    }

    /// Title + caption on the left, a menu picker on the right (wraps under at large type sizes).
    private func pickerRow(_ title: String, _ sub: String, selection: Binding<String>,
                           options: [(String, String)]) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.m))
        return layout {
            pickerLabel(title, sub)
                .frame(maxWidth: .infinity, alignment: .leading)
            pickerMenu(title, selection: selection, options: options)
        }
    }

    private func pickerLabel(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).typo(.headline).foregroundStyle(Theme.ink)
            Text(sub).typo(.caption).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pickerMenu(_ title: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.menu)
        .tint(Theme.ink)
        .frame(minHeight: 44)
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
