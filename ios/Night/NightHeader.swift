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
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(boardName)
                        .font(NightStyle.title(46))
                        .tracking(-1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.opacity)
                    Image(systemName: "chevron.down")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(NightStyle.secondary)
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("board, \(boardName)")
            .accessibilityHint("switches to another board")
            .accessibilityIdentifier("nightBoardMenu")

            Text(line)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NightStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nightHeaderLine")

            if isShared {
                NightFilterPicker(filter: $filter).padding(.top, 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? Color.black : Color.white.opacity(0.8))
                        .padding(.horizontal, 18)
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
        .sensoryFeedback(.selection, trigger: filter)
    }
}

struct NightMembers: View {
    let members: [NightMember]

    var body: some View {
        HStack(spacing: -9) {
            ForEach(members.prefix(4)) { member in
                NightAvatar(name: member.name, colorName: member.color, personId: member.id, size: 30)
                    .overlay { Circle().strokeBorder(NightStyle.ink.opacity(0.8), lineWidth: 2) }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(members.count) people: \(members.map(\.name).joined(separator: ", "))")
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
            Label("switch the view", systemImage: "square.stack.3d.up")
        }
        .accessibilityIdentifier("nightViewMenu")
    }
}
