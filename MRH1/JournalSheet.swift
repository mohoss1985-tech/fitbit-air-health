import SwiftUI

/// Journal tags (+ on Today). Text chips only, no emoji. Tags toggle for the chosen day
/// (today by default, or yesterday for things like a late meal noticed the morning after).
struct JournalSheet: View {
    @Environment(JournalStore.self) private var journal
    @Environment(\.dismiss) private var dismiss

    private enum Day: String, Hashable { case today = "Today", yesterday = "Yesterday" }
    @State private var day: Day = .today
    @State private var newTag = ""
    @FocusState private var adding: Bool

    private var date: Date {
        day == .today ? Demo.now
            : (Calendar.current.date(byAdding: .day, value: -1, to: Demo.now) ?? Demo.now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("What shaped your day?").typo(.title).foregroundStyle(Theme.ink)
                        Text("Tap the tags that apply. After \(JournalStore.discoveryThreshold) tagged days, Today shows what moves your sleep and recovery.")
                            .typo(.body).foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PillPicker(selection: $day, options: [.today, .yesterday]) { $0.rawValue }

                    FlowLayout(spacing: Space.s) {
                        ForEach(journal.tags, id: \.self) { tag in
                            chip(tag)
                        }
                    }

                    HStack(spacing: Space.s) {
                        TextField("Add your own tag", text: $newTag)
                            .typo(.body)
                            .focused($adding)
                            .submitLabel(.done)
                            .onSubmit(add)
                            .padding(.horizontal, Space.l)
                            .frame(minHeight: 44)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
                        if !newTag.trimmingCharacters(in: .whitespaces).isEmpty {
                            RoundIconButton(systemName: "plus", label: "Add tag", action: add)
                        }
                    }

                    if let p = journal.progressText {
                        Text(p + ".").typo(.caption).foregroundStyle(Theme.graphite)
                    }
                    Text("Tags stay on this iPhone.")
                        .typo(.caption).foregroundStyle(Theme.graphite)
                }
                .padding(Space.gutter)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .typo(.headline)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.paper)
    }

    private func chip(_ tag: String) -> some View {
        let on = journal.isOn(tag, date: date)
        return Button {
            journal.toggle(tag: tag, on: !on, date: date)
        } label: {
            Text(tag)
                .typo(.label)
                .foregroundStyle(on ? Theme.paper : Theme.ink)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .fill(on ? Theme.ink : Theme.card)
                )
                .contentShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(tag)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func add() {
        let t = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        journal.addTag(t)
        journal.toggle(tag: t, on: true, date: date)
        newTag = ""
        adding = false
    }
}

/// Wrapping row layout for tag chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.init(width: width, height: nil))
            if x > 0 && x + size.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.init(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .init(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
