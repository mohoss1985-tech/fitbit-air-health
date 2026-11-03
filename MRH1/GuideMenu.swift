import SwiftUI

// MARK: - Results guide (menu)

struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                Text("Every result is compared with your own normal: your average over recent nights, plus or minus one usual day-to-day swing.")
                    .typo(.body)
                    .foregroundStyle(Theme.graphite)

                group("Colours") {
                    colourRow(.inRange, "Inside your usual range, or outside it in the good direction, like more steps than usual.")
                    colourRow(.watch, "Outside your usual range in the direction that matters. Worth a look, not a worry.")
                    colourRow(.outOfRange, "Well outside your usual range, more than one usual swing past its edge.")
                    row("Ember dot", "Today’s value on the range bar while it sits inside your usual band.")
                    row("Grey, “Not sent”", "Google Health doesn’t send this to Apple Health yet, so it’s left out instead of shown as zero.")
                }

                group("Scores") {
                    row("Recovery", "0–100 %. How ready your body is today, from HRV, resting heart rate, breathing rate and sleep, each against your own normal. In range 67 and up, Watch 34–66, Out of range under 34. Without HRV it uses 3 of 4 signals.")
                    row("Strain", "0–21. All-day load on your heart, from your heart rate. Each step up is harder to reach: 10–13 moderate, 14–17 high, 18 and up all out.")
                    row("Sleep score", "0–100. Time asleep vs an 8 h need (50 points), deep and REM share (30 points) and how much of your time in bed you slept (20 points).")
                    row("Early reads", "Your normal takes 14 nights to learn. Until then results say how many baseline days they have.")
                }

                ForEach(Panel.allCases) { panel in
                    group(panel.title) {
                        ForEach(panel.metrics) { id in
                            row(id.info.name, guideText(id))
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
        .navigationTitle("Results guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideText(_ id: MetricID) -> String {
        var text = id.info.what
        if !id.info.typicalText.isEmpty { text += " Typical adult: \(id.info.typicalText)." }
        if id.isNotSentByGoogle { text += " Not sent by Google Health yet." }
        return text
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(title).padding(.horizontal, Space.xs)
            Card(spacing: Space.l) { content() }
        }
    }

    private func colourRow(_ tier: StatusTier, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            StatusChip(tier: tier)
            Text(text).typo(.body).foregroundStyle(Theme.graphite)
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).typo(.headline).foregroundStyle(Theme.ink)
            Text(text).typo(.body).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
