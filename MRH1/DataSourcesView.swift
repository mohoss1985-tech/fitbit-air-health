import SwiftUI

// MARK: - Data sources (the v0.1 check screen, now in the menu)

struct DataSourcesView: View {
    @Environment(HealthStore.self) private var health

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    FreshnessChip(date: health.latestSampleDate ?? health.lastRefresh)
                    Text("What Apple Health has from the last 7 days.")
                        .typo(.body).foregroundStyle(Theme.graphite)
                }

                Card(padding: 0, spacing: 0) {
                    ForEach(Array(health.sourceRows.enumerated()), id: \.element.id) { i, row in
                        if i > 0 {
                            Rectangle().fill(Theme.hair).frame(height: 0.5).padding(.leading, Space.gutter)
                        }
                        sourceRow(row)
                    }
                    if health.sourceRows.isEmpty {
                        Text("Waiting for sync").typo(.body).foregroundStyle(Theme.graphite).padding(Space.gutter)
                    }
                }

                Text("Google Health sends data to Apple Health in batches, so the latest night can arrive a few hours late. Open Google Health to nudge it, then pull down here.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.section)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Data sources")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await health.refresh() }
    }

    private func sourceRow(_ row: HealthStore.SourceRow) -> some View {
        let has = row.samples7d > 0
        return VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).typo(.headline).foregroundStyle(Theme.ink)
                Spacer(minLength: Space.s)
                Text(row.latestValue)
                    .typo(.label)
                    .foregroundStyle(has ? Theme.ink : Theme.graphite)
                    .multilineTextAlignment(.trailing)
            }
            HStack(spacing: Space.s) {
                Circle().fill(has ? Theme.good : Theme.graphite2).frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(has ? "\(row.samples7d) samples" : "No samples")
                if let date = row.latestDate {
                    Text(date.formatted(.relative(presentation: .named)))
                }
            }
            .typo(.caption)
            .foregroundStyle(Theme.graphite)
            if !row.sources.isEmpty {
                Text(row.sources.joined(separator: ", ")).typo(.micro).foregroundStyle(Theme.graphite)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.l)
        .accessibilityElement(children: .combine)
    }
}
