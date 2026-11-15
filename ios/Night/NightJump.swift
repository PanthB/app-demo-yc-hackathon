import SwiftUI

struct NightJumpRow: View {
    let sections: [DropSection]
    let current: String?
    let jump: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(sections) { section in
                            let isOn = section.id == current
                            Button {
                                jump(section.id)
                            } label: {
                                Text(section.title)
                                    .font(NightStyle.body.weight(.semibold))
                                    .foregroundStyle(isOn ? Color.black : Color.white.opacity(0.85))
                                    .lineLimit(1)
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                                    .background {
                                        if isOn { Capsule().fill(.white) }
                                    }
                                    .contentShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                            .accessibilityHint("scrolls to this group")
                            .accessibilityIdentifier("nightJump-\(section.id)")
                            .id(section.id)
                        }
                    }
                    .padding(.horizontal, NightStyle.margin)
                    .padding(.vertical, 6)
                }
            }
            .scrollIndicators(.hidden)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .onChange(of: current) { _, id in
                guard let id else { return }
                withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

struct NightReadingRing: View {
    let createdAt: Date

    @State private var isOver = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isOver {
                EmptyView()
            } else if reduceMotion {
                NightStyle.card.strokeBorder(.tint.opacity(0.6), lineWidth: 2)
            } else {
                TimelineView(.animation) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
                    ZStack {
                        segment(from: phase, to: phase + 0.22)
                        if phase + 0.22 > 1 { segment(from: 0, to: phase + 0.22 - 1) }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            let left = 60 - Date.now.timeIntervalSince(createdAt)
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { isOver = true }
        }
    }

    private func segment(from start: Double, to end: Double) -> some View {
        NightStyle.card
            .trim(from: start, to: min(end, 1))
            .stroke(.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
}
