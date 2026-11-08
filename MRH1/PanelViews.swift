import SwiftUI

// MARK: - Body tab (lab panels)
//
// DESIGN_SPEC §4 Body: one summary sentence, a black-pill picker Heart · Lungs · Sleep · Activity,
// then every result as a row: label · value + unit · status chip · ribbon / range strip · 7-day line.
// Rows open MetricSheet. Missing data uses the three explicit states (§5), never a zero.

struct PanelsView: View {
    @Environment(HealthStore.self) private var health
    @State private var panel: Panel
    @Environment(AppNav.self) private var nav: AppNav?
    @Environment(\.isPresented) private var isPushed
    @State private var sheet: MetricState?

    init(initial: Panel = .heart) {
        _panel = State(initialValue: initial)
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header
                PillPicker(selection: $panel, options: Panel.allCases) { $0.short }
                    .accessibilityLabel("Panel")
                PanelResults(panel: panel, onOpen: { sheet = $0 })
                    .id(panel)
                    .transition(.opacity)
                MetabolicCard().id("metabolic")
                BodyFooter()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.section)
            .animation(.easeOut(duration: 0.2), value: panel)
        }
        .onAppear {
            // Screenshot hook (same family as -tab / -open): `-scroll metabolic` lands on the new card.
            if ProcessInfo.processInfo.arguments.contains("metabolic") { proxy.scrollTo("metabolic", anchor: .top) }
        }
        }
        .background(Theme.paper)
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPushed, nav != nil {
                ToolbarItem(placement: .topBarLeading) { MenuButton(inToolbar: true) }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Body").typo(.headline).foregroundStyle(Theme.ink)
                    Text("\(Panel.allCases.count) panels, \(BodyCopy.resultCount) results")
                        .typo(.caption).monospacedDigit().foregroundStyle(Theme.graphite)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .refreshable { await health.refresh() }
        .sheet(item: $sheet) { MetricSheet(state: $0) }
    }

    // MARK: Summary sentence

    private var header: some View {
        let states = MetricID.allCases.map { health.state($0) }
        let shared = states.filter(\.hasData)
        let watch = shared.filter(\.isConcern).count
        let sentence: String
        let detail: String
        if shared.isEmpty {
            sentence = health.isLoading ? "Reading Apple Health…" : "No results yet."
            detail = "Results appear after Google Health syncs your Fitbit Air to Apple Health."
        } else if watch == 0 {
            sentence = "All \(shared.count) results in your usual range."
            detail = "Latest readings against your own normal."
        } else {
            sentence = watch == 1 ? "1 result to watch today." : "\(watch) results to watch today."
            detail = "Latest readings against your own normal."
        }
        return VStack(alignment: .leading, spacing: Space.s) {
            Text(sentence)
                .typo(.title)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .typo(.body)
                .foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - One panel, every result (reachable via Route.panel)

struct PanelDetailView: View {
    @Environment(HealthStore.self) private var health
    let panel: Panel
    @State private var sheet: MetricState?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                PanelResults(panel: panel, onOpen: { sheet = $0 })
                BodyFooter()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.section)
        }
        .background(Theme.paper)
        .navigationTitle(panel.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await health.refresh() }
        .sheet(item: $sheet) { MetricSheet(state: $0) }
    }
}

// MARK: - Panel card

private struct PanelResults: View {
    @Environment(HealthStore.self) private var health
    let panel: Panel
    let onOpen: (MetricState) -> Void

    var body: some View {
        let states = panel.metrics.map { health.state($0) }
        let shared = states.filter(\.hasData)
        let watch = shared.filter(\.isConcern).count
        let early = shared.map(\.baselineDays).min() ?? MetricState.fullBaselineDays

        VStack(alignment: .leading, spacing: Space.m) {
            Card {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(panel.title).typo(.headline).foregroundStyle(Theme.ink)
                        Spacer(minLength: Space.s)
                        Text(panelStatus(shared: shared.count, total: states.count, watch: watch))
                            .typo(.label).monospacedDigit().foregroundStyle(Theme.graphite)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, Space.s)

                    ForEach(states) { s in
                        Rectangle().fill(Theme.hair).frame(height: 0.5)
                        if !s.hasData, BodyCopy.notSentByGoogle.contains(s.id) {
                            NotSentRow(title: s.id.info.name, sub: shortSub(s.id), why: BodyCopy.why(s.id)) { onOpen(s) }
                        } else {
                            ResultRow(state: s, missing: missingKind(s)) { onOpen(s) }
                        }
                    }

                    if panel == .activity {
                        Rectangle().fill(Theme.hair).frame(height: 0.5)
                        NotSentRow(title: "VO2 max", sub: "Cardio fitness",
                                   why: "Google Health doesn’t send VO2 max to Apple Health yet. It appears here if that changes.",
                                   onTap: nil)
                    }
                    if panel == .heart {
                        Rectangle().fill(Theme.hair).frame(height: 0.5)
                        BloodPressureRow()
                    }
                }
            }

            if !shared.isEmpty, early < MetricState.fullBaselineDays {
                Text("Early read: \(early) of \(MetricState.fullBaselineDays) baseline days. Ranges settle as nights add up.")
                    .typo(.caption).monospacedDigit().foregroundStyle(Theme.graphite)
                    .padding(.horizontal, Space.gutter)
            }
        }
    }

    private func panelStatus(shared: Int, total: Int, watch: Int) -> String {
        if shared == 0 { return "Waiting for sync" }
        // Metrics Google Health never sends aren't "out of range", so don't count them against you.
        if watch == 0 { return shared == total ? "All in range" : "All \(shared) in range · \(total - shared) not sent" }
        return watch == 1 ? "1 to watch" : "\(watch) to watch"
    }

    /// Maps C's MissingState (HealthStore.missing) to A's NotSentKind. Before the first refresh
    /// everything reads "Waiting for sync" rather than "No reading".
    private func missingKind(_ s: MetricState) -> NotSentKind? {
        guard let m = health.missing(s.id) else { return nil }
        if !s.hasData, m != .notSent, health.isLoading || health.lastRefresh == nil { return .waiting }
        switch m {
        case .notSent: return .notSent
        case .waiting: return .waiting
        case .noReading: return .noReading
        }
    }

    private func shortSub(_ id: MetricID) -> String {
        switch id {
        case .hrv: return "HRV"
        case .skinTemp: return "Change vs your usual night"
        default: return id.info.sub
        }
    }
}

// MARK: - Result row (label · value + unit · chip · ribbon/strip · 7-day line)

private struct ResultRow: View {
    @Environment(AppNav.self) private var nav
    let state: MetricState
    let missing: NotSentKind?
    let onTap: () -> Void

    private var info: MetricInfo { state.id.info }
    /// Vitals use the dot-matrix range strip (§3); sleep and activity use the baseline ribbon.
    private var isVital: Bool { info.panel == .heart || info.panel == .lungs }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(alignment: .top, spacing: Space.m) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(info.name).typo(.body).foregroundStyle(Theme.ink)
                        Text(BodyCopy.rangeLine(state, missing: missing))
                            .typo(.caption).monospacedDigit().foregroundStyle(Theme.graphite)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: Space.xs) {
                        if state.hasData {
                            ValueText(value: state.valueText, unit: BodyCopy.unit(state.id), size: .headline)
                            StatusChip(state: state)
                        } else {
                            Text("—").typo(.headline).foregroundStyle(Theme.graphite)
                            NotSentLabel(kind: missing ?? .noReading)
                        }
                    }

                    // v1.1: CoachMark at the row's top-right, level with the value.
                    CoachMarkSlot(metric: state.id)
                        .padding(.top, 4)
                }

                if state.hasData {
                    HStack(alignment: .center, spacing: Space.l) {
                        Group {
                            if isVital { RangeStrip(state: state) } else { BaselineRibbon(state: state) }
                        }
                        .frame(maxWidth: .infinity)
                        Sparkline(values: state.spark, color: Theme.ink)
                            .frame(width: 64, height: 24)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, Space.l)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BodyCopy.accessibility(state, missing: missing))
        .accessibilityHint("Opens what this result means")
        .accessibilityAddTraits(.isButton)
        .coachAccessibilityAction { nav.openCoach(about: state.id) }
    }
}

// MARK: - Missing-data rows

/// HRV, skin temperature, VO2 max: Google Health doesn't write them to Apple Health.
private struct NotSentRow: View {
    let title: String
    let sub: String
    let why: String
    let onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(PressStyle())
                .accessibilityHint("Opens what this result means")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .top, spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title).typo(.body).foregroundStyle(Theme.ink)
                    Text(sub).typo(.caption).foregroundStyle(Theme.graphite)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NotSentLabel(kind: .notSent)
            }
            Text(why)
                .typo(.caption).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.l)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). Not sent by Google Health. \(why)")
    }
}

/// The Fitbit Air has no blood-pressure sensor; say so instead of leaving a gap.
private struct NoSensorRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text("Blood pressure").typo(.body).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("No sensor").typo(.label).foregroundStyle(Theme.graphite)
            }
            Text("Fitbit Air has no blood-pressure sensor, so MRH1 can’t show it.")
                .typo(.caption).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.l)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Footer

private struct BodyFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Your normal is the last 30 days. The line shows the last 7. Tap a result for what it means.")
            Text("Wellness estimates, not medical advice.")
        }
        .typo(.caption)
        .foregroundStyle(Theme.graphite)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Copy and small helpers (Body only)

private enum BodyCopy {
    static let notSentByGoogle: Set<MetricID> = MetricID.allCases.filter(\.isNotSentByGoogle).reduce(into: []) { $0.insert($1) }
    /// 13 metrics + VO2 max + blood pressure note are rows; results = metrics + VO2 max.
    static let resultCount = MetricID.allCases.count + 1

    static func rangeLine(_ s: MetricState, missing: NotSentKind? = nil) -> String {
        if s.hasData, missing == .waiting { return "Last value shown. Waiting for sync" }
        if s.hasData, s.baseline == nil, let early = s.earlyReadText { return early }
        if let b = s.baseline {
            if s.id == .skinTemp { return "Your normal ±" + String(format: "%.1f", locale: .current, b.sd) + "\u{00A0}°C" }
            let day = (s.id == .steps || s.id == .energy) ? "Yesterday · " : (s.id == .workoutMinutes ? "Last 7 days · " : "")
            return day + "Your normal " + s.id.format(b.low) + "–" + s.id.format(b.high)
        }
        return "Typical " + s.id.info.typicalText
    }

    /// Sleep durations carry their own units ("7 h 05"); everything else gets the metric unit.
    static func unit(_ id: MetricID) -> String { id.info.unit }

    static func why(_ id: MetricID) -> String {
        switch id {
        case .hrv: return "Google Health doesn’t write HRV to Apple Health yet. Recovery uses the other inputs."
        case .skinTemp: return "Google Health doesn’t send skin temperature to Apple Health yet. It appears here if that changes."
        default: return ""
        }
    }

    static func accessibility(_ s: MetricState, missing: NotSentKind?) -> String {
        let info = s.id.info
        guard s.hasData else { return "\(info.name). \((missing ?? .noReading).text)." }
        let unit = info.unit.isEmpty ? "" : " \(info.unit)"
        let last7 = s.spark.map { s.id.format($0) }.joined(separator: ", ")
        return "\(info.name), \(s.valueText)\(unit). \(s.statusWord), \(s.directionText). \(rangeLine(s, missing: missing)). Last 7 days: \(last7)."
    }
}
