import SwiftUI

// MARK: - Swipeable day cards ("Your week" on Today)

/// Horizontal day cards, newest on the right. The day circles in the Week segment of Today
/// select a card through `selected`.
struct WeekStrip: View {
    @Environment(HealthStore.self) private var health
    @Binding var selected: Date?
    @State private var ownSelection: Date?
    private let external: Bool

    init(selected: Binding<Date?>) {
        _selected = selected
        external = true
    }

    /// v0.4 call site (no selection from outside).
    init() {
        _selected = .constant(nil)
        external = false
    }

    private var selection: Binding<Date?> {
        external ? $selected : $ownSelection
    }

    var body: some View {
        let days = Array(health.history.suffix(7))
        VStack(alignment: .leading, spacing: Space.m) {
            Text(headline(days))
                .typo(.body).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Space.cardGap) {
                    ForEach(days) { d in
                        dayCard(d)
                            .containerRelativeFrame(.horizontal, count: 2, spacing: Space.cardGap)
                            .id(d.date)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: selection, anchor: .center)
            .defaultScrollAnchor(.trailing)
            .scrollClipDisabled()
        }
    }

    private func headline(_ days: [DaySummary]) -> String {
        let rec = days.compactMap(\.recovery)
        guard !rec.isEmpty else { return "Your week fills in as nights sync." }
        let avg = rec.reduce(0, +) / rec.count
        return "Recovery averaged \(avg)% over the last \(days.count) days."
    }

    private func tier(_ r: Int?) -> StatusTier? {
        guard let r else { return nil }
        return r >= 67 ? .inRange : (r >= 34 ? .watch : .outOfRange)
    }

    private func dayCard(_ d: DaySummary) -> some View {
        let isToday = Calendar.current.isDate(d.date, inSameDayAs: Demo.now)
        let isSelected = selection.wrappedValue.map { Calendar.current.isDate($0, inSameDayAs: d.date) } ?? false
        let t = tier(d.recovery)
        return VStack(alignment: .leading, spacing: Space.m) {
            Text(isToday ? "Today" : d.date.formatted(.dateTime.weekday(.wide).day()))
                .typo(.label).foregroundStyle(Theme.ink)
            HStack(spacing: Space.m) {
                TickRing(progress: Double(d.recovery ?? 0) / 100,
                         color: t?.fill ?? Theme.hair,
                         size: 56, ticks: 24, animateOnAppear: false) {
                    Text(d.recovery.map { "\($0)" } ?? "—")
                        .typo(.label)
                        .foregroundStyle(d.recovery == nil ? Theme.graphite : Theme.ink)
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    row("moon", d.sleepMinutes.map { MetricID.sleepTotal.format($0) } ?? "—")
                    row("flame", d.strain.map { String(format: "%.1f", locale: .current, $0) } ?? "—")
                    row("figure.walk", d.steps.map { Int($0).formatted() } ?? "—")
                }
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(Theme.ink.opacity(isSelected ? 0.5 : 0), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isToday ? "Today" : d.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue([
            d.recovery.map { "Recovery \($0) percent, \(t?.word ?? "")" } ?? "Recovery, no reading",
            d.sleepMinutes.map { "Slept \(MetricID.sleepTotal.format($0))" } ?? "Sleep, no reading",
            d.strain.map { String(format: "Strain %.1f", locale: .current, $0) } ?? "Strain, no reading",
            d.steps.map { "\(Int($0).formatted()) steps" } ?? "Steps, no reading"
        ].joined(separator: ". "))
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: icon).font(.caption).foregroundStyle(Theme.graphite).frame(width: 16)
            Text(text).typo(.label).foregroundStyle(Theme.ink)
        }
    }
}
