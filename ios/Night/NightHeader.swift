import SwiftUI

struct NightBoardChoice: Identifiable, Equatable {
    let id: String
    let name: String
}

struct NightMember: Identifiable, Equatable {
    let id: String
    let name: String
    let color: String?
}

struct NightHeader: View {
    let boardName: String
    let boards: [NightBoardChoice]
    let currentBoardId: String
    let line: String
    let isShared: Bool
    @Binding var filter: DropFilter
    let showBoard: (String) -> Void
    let startBoard: () -> Void
    let joinBoard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                ForEach(boards) { board in
                    Button {
                        showBoard(board.id)
                    } label: {
                        if board.id == currentBoardId {
                            Label(board.name, systemImage: "checkmark")
                        } else {
                            Text(board.name)
                        }
                    }
                }
                Divider()
                Button("start a shared board", systemImage: "plus") { startBoard() }
                Button("join with a code", systemImage: "person.badge.plus") { joinBoard() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(boardName)
                        .font(NightStyle.pageTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.opacity)
                    Image(systemName: "chevron.down")
                        .font(NightStyle.heading)
                        .foregroundStyle(NightStyle.secondary)
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("board, \(boardName)")
            .accessibilityHint("switches to another board")
            .accessibilityIdentifier("nightBoardMenu")

            Text(line)
                .font(NightStyle.body)
                .foregroundStyle(NightStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nightHeaderLine")

            if isShared {
                NightFilterPicker(filter: $filter).padding(.top, 8)
            }
        }
        .padding(.horizontal, NightStyle.margin)
        .padding(.top, 8)
    }
}

struct NightFilterPicker: View {
    @Binding var filter: DropFilter
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DropFilter.allCases, id: \.self) { option in
                let isOn = option == filter
                Button {
                    withAnimation(NightStyle.motion(reduceMotion, .snappy(duration: 0.3))) { filter = option }
                } label: {
                    Text(option.rawValue)
                        .font(NightStyle.body.weight(.semibold))
                        .foregroundStyle(isOn ? Color.black : Color.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background {
                            if isOn {
                                Capsule().fill(.white).matchedGeometryEffect(id: "filter", in: namespace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("nightFilter-\(option.rawValue)")
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sensoryFeedback(.selection, trigger: filter)
    }
}

struct NightMembers: View {
    let members: [NightMember]
    let streaks: [String: DailyStreak]
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: -6) {
                ForEach(members.prefix(4)) { member in
                    NightAvatar(name: member.name, colorName: member.color, personId: member.id)
                        .padding(1.5)
                        .background(NightStyle.ink, in: .circle)
                }
            }
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(members.map { member in
            let days = streaks[member.id]?.days ?? 0
            return days > 1 ? "\(member.name), \(days) day streak" : member.name
        }.joined(separator: ", "))
        .accessibilityHint("shows everyone's streaks")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("nightMembers")
    }
}

struct NightViewMenu: View {
    @AppStorage(ViewMode.storageKey) private var storedView: String?

    var body: some View {
        Menu {
            Button("list", systemImage: "list.bullet") { storedView = ViewMode.list.rawValue }
            Button("cards", systemImage: "square.grid.2x2") { storedView = ViewMode.cards.rawValue }
            Button("board", systemImage: "rectangle.on.rectangle.angled") { storedView = ViewMode.board.rawValue }
        } label: {
            Text("views")
        }
        .accessibilityHint("switches to list, cards or board")
        .accessibilityIdentifier("nightViewMenu")
    }
}
