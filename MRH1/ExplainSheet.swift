import SwiftUI

enum SleepInfo: Int, Identifiable {
    case debt, consistency
    var id: Int { rawValue }
}

// MARK: - Simple explanation sheet (for scores that are not single metrics)

/// Stress, sleep debt, consistency and body age. Same paper/card grammar as MetricSheet.
struct ExplainSheet: View {
    let title: String
    let sub: String
    let what: String
    let rows: [(String, String)]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title).typo(.title).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(sub).typo(.body).foregroundStyle(Theme.graphite)
                }

                Text(what)
                    .typo(.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rows.indices, id: \.self) { i in
                            if i > 0 { Rectangle().fill(Theme.hair).frame(height: 0.5) }
                            row(rows[i].0, rows[i].1)
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
                }

                SheetDisclaimer()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.section)
            .padding(.bottom, Space.xl)
        }
        .background(Theme.card)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.card)
        .presentationCornerRadius(Radius.card)
    }

    @ViewBuilder private func row(_ label: String, _ text: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.m))
        layout {
            Text(label)
                .typo(.label)
                .foregroundStyle(Theme.ink)
                .frame(width: typeSize.isAccessibilitySize ? nil : 112, alignment: .leading)
            Text(text)
                .typo(.body)
                .foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Space.m)
        .accessibilityElement(children: .combine)
    }
}

/// Footer used by every sheet (keeps the v0.4 line and the v1 wording).
struct SheetDisclaimer: View {
    var body: some View {
        Text("Wellness estimates, not medical advice. Readings come from a wrist sensor, not a medical test.")
            .typo(.caption)
            .foregroundStyle(Theme.graphite)
            .fixedSize(horizontal: false, vertical: true)
    }
}
