import SwiftUI

/// The example drops the guide plays with. They're illustration, not seed data, so they ship in every build.
struct GuideSample: Identifiable, Hashable {
    enum Person: Hashable {
        case you, maya, sam, alex

        var initial: String {
            switch self {
            case .you: ""
            case .maya: "m"
            case .sam: "s"
            case .alex: "a"
            }
        }

        var color: Color {
            switch self {
            case .you: .orange
            case .maya: .blue
            case .sam: .green
            case .alex: .pink
            }
        }
    }

    let id: String
    let kind: DropKind
    let title: String
    let meta: String
    let image: String?
    let aspect: CGFloat
    let person: Person

    static let width: CGFloat = 120
    static let previewWidth: CGFloat = width - 12

    var height: CGFloat {
        Self.previewWidth / aspect + 38
    }

    static let song = GuideSample(id: "song", kind: .song, title: "san francisco", meta: "scott mckenzie", image: "guide-song", aspect: 1, person: .you)
    static let place = GuideSample(id: "place", kind: .place, title: "tartine bakery", meta: "the mission", image: "guide-place", aspect: 4 / 3, person: .sam)
    static let clip = GuideSample(id: "clip", kind: .video, title: "dolores park", meta: "tiktok", image: "guide-clip", aspect: 3 / 4, person: .maya)
    static let link = GuideSample(id: "link", kind: .link, title: "mission history", meta: "wikipedia", image: nil, aspect: 4 / 3, person: .alex)
    static let ramen = GuideSample(id: "ramen", kind: .place, title: "marufuku", meta: "japantown", image: "board-ramen", aspect: 4 / 3, person: .sam)
    static let bridge = GuideSample(id: "bridge", kind: .video, title: "fort point", meta: "instagram", image: "board-goldengate", aspect: 3 / 4, person: .alex)
    static let night = GuideSample(id: "night", kind: .song, title: "dreams", meta: "fleetwood mac", image: "board-night", aspect: 1, person: .maya)

    static let guide: [GuideSample] = [song, place, clip, link, ramen, night]
}

extension EnvironmentValues {
    @Entry var guideOwnBoard = false
}

/// A drop on the guide's board: the picture with its kind and who added it, and one line of title.
struct GuideCard: View {
    let sample: GuideSample
    @Environment(\.guideOwnBoard) private var ownBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            preview
                .frame(width: GuideSample.previewWidth, height: GuideSample.previewWidth / sample.aspect)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    KindPill(kind: sample.kind)
                        .scaleEffect(0.82, anchor: .topLeading)
                        .padding(5)
                }
                .overlay(alignment: .bottomTrailing) {
                    GuideAvatar(person: ownBoard ? .you : sample.person, size: 20)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                        .padding(6)
                }
            Text(sample.title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(height: 20, alignment: .leading)
                .padding(.horizontal, 2)
        }
        .padding(6)
        .frame(width: GuideSample.width, alignment: .leading)
        .background(Color(white: 0.13), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var preview: some View {
        if let image = sample.image {
            Color.clear
                .overlay {
                    Image(image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .overlay {
                    if sample.kind == .video {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .glassEffect(.regular, in: .circle)
                    }
                }
        } else {
            ZStack(alignment: .bottomLeading) {
                Color(red: 0.106, green: 0.114, blue: 0.180)
                VStack(alignment: .leading, spacing: 2) {
                    Text("W")
                        .font(.system(size: 30, weight: .regular, design: .serif))
                    Text(sample.meta)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
        }
    }
}

/// A drop as a bare picture, for the welcome's fan.
struct GuideTile: View {
    let sample: GuideSample
    let width: CGFloat

    var body: some View {
        Color.clear
            .frame(width: width, height: width / sample.aspect)
            .overlay {
                Image(sample.image ?? "guide-song")
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(.rect(cornerRadius: width * 0.2, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.2, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
            .environment(\.colorScheme, .dark)
    }
}

struct GuideAvatar: View {
    let person: GuideSample.Person
    var size: CGFloat = 13

    var body: some View {
        ZStack {
            Circle().fill(person.color)
            if person == .you {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
            } else {
                Text(person.initial)
                    .font(.system(size: size * 0.58, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
    }
}
