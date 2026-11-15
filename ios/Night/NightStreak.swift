import SwiftUI

struct NightStreakChip: View {
    let streak: DailyStreak
    let moment: Int
    let open: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: open) {
            HStack(spacing: 4) {
                NightEmber(droppedToday: streak.droppedToday, moment: moment, size: 26)
                Text("\(streak.days)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(streak.days)))
            }
            .font(NightStyle.itemTitle)
            .padding(.horizontal, 4)
            .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? 0 : moment) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.0, duration: 0.01)
                SpringKeyframe(1.2, duration: 0.2, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sensoryFeedback(.success, trigger: moment)
        .accessibilityLabel(streak.days == 1 ? "your streak, one day" : "your streak, \(streak.days) days")
        .accessibilityHint(streak.isWaitingOnToday ? "drop something today to keep it going" : "shows everyone's streaks")
        .accessibilityIdentifier("nightStreakChip")
    }
}

struct NightEmber: View {
    let droppedToday: Bool
    let moment: Int
    let size: CGFloat

    @State private var isBlinking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(isBlinking ? "ember-saved" : droppedToday ? "ember-awake" : "ember-rest")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .task(id: moment) {
                guard moment > 0, droppedToday, !reduceMotion else { return }
                try? await Task.sleep(for: .seconds(0.25))
                isBlinking = true
                try? await Task.sleep(for: .seconds(0.45))
                isBlinking = false
            }
    }
}

struct NightStreakSheet: View {
    static func crewLine(_ crew: DailyStreak) -> String {
        switch (crew.days, crew.droppedToday) {
        case (0, _): "the crew's streak starts with the next drop."
        case (1, true): "the crew dropped something today, so its streak just started."
        case (1, false): "the crew dropped something yesterday. one today keeps it going."
        default: "the crew is on a \(crew.days) day run."
        }
    }

    let boardName: String
    let streaks: BoardStreaks
    let members: [NightMember]
    let me: String
    let isShared: Bool
    var invite: URL?
    var inviteCode: String?

    @State private var contentHeight: CGFloat = 320

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        NightEmber(droppedToday: streaks.mine.droppedToday, moment: 0, size: 48)
                        Text(streaks.mine.days == 1 ? "1 day" : "\(streaks.mine.days) days").monospacedDigit()
                    }
                    .font(NightStyle.pageTitle)
                    .accessibilityElement(children: .combine)
                    Text(streaks.headline)
                        .font(NightStyle.body)
                        .foregroundStyle(NightStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                WeekStrip(days: streaks.myWeek, label: "your week in \(boardName)")

                if isShared, let invite, let inviteCode {
                    HStack(spacing: 12) {
                        Text("the code is \(inviteCode).")
                            .font(NightStyle.body)
                            .foregroundStyle(NightStyle.secondary)
                            .monospacedDigit()
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                        ShareLink(item: invite, subject: Text("join \(boardName)"), message: Text("join \(boardName) with me. the code is \(inviteCode).")) {
                            Text("invite friends")
                        }
                        .buttonStyle(NightPrimaryButtonStyle())
                        .accessibilityIdentifier("nightInvite")
                    }
                }

                if isShared {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(Self.crewLine(streaks.crew))
                            .font(NightStyle.itemTitle)
                        WeekStrip(days: streaks.crewWeek, label: "the crew's week")
                        VStack(spacing: 12) {
                            ForEach(members) { member in
                                let streak = streaks.members[member.id] ?? .none
                                HStack(spacing: 8) {
                                    NightAvatar(name: member.name, colorName: member.color, personId: member.id)
                                    Text(member.id == me ? "\(member.name) (you)" : member.name).font(NightStyle.body)
                                    Spacer()
                                    Label(streak.days == 1 ? "1 day" : "\(streak.days) days", systemImage: streak.droppedToday ? "flame.fill" : "flame")
                                        .font(NightStyle.body)
                                        .fontWeight(NightStyle.symbolWeight)
                                        .monospacedDigit()
                                        .foregroundStyle(streak.isAlive ? NightStyle.flame : NightStyle.tertiary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                Text("a streak counts the days in a row you drop something here. it stays alive until the end of today.")
                    .font(NightStyle.body)
                    .foregroundStyle(NightStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(NightStyle.margin)
            .padding(.top, 8)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollIndicators(.hidden)
        .presentationDetents(isShared ? [.medium, .large] : [.height(contentHeight + 24)])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("nightStreakSheet")
    }
}

private struct WeekStrip: View {
    let days: [Bool]
    let label: String

    private static let letters = ["s", "m", "t", "w", "t", "f", "s"]

    var body: some View {
        let today = Calendar.current.component(.weekday, from: .now) - 1
        HStack(spacing: 0) {
            ForEach(days.indices, id: \.self) { index in
                let weekday = (today - (days.count - 1 - index) + 70) % 7
                VStack(spacing: 8) {
                    Circle()
                        .fill(days[index] ? NightStyle.flame : Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if index == days.count - 1 {
                                Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2).padding(-4)
                            }
                        }
                    Text(Self.letters[weekday])
                        .font(NightStyle.caption)
                        .foregroundStyle(NightStyle.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(days.filter { $0 }.count) of the last 7 days")
    }
}
