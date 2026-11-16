import SwiftUI

@MainActor
@Observable
final class NightFlightModel {
    var drop: Drop?
    var from: CGPoint = .zero
    var target: CGRect?
    var lifted = false
    var popped = false
    @ObservationIgnored var bubbleFrames: [UUID: CGRect] = [:]

    func start(_ drop: Drop, from: CGPoint) {
        self.drop = drop
        self.from = from
        target = nil
        lifted = false
        popped = false
    }

    func end() {
        drop = nil
        target = nil
        lifted = false
        popped = false
    }
}

struct NightQueue: View {
    let drops: [Drop]
    let flight: NightFlightModel

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(drops) { drop in
                    NightBubble(drop: drop, reading: true)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { flight.bubbleFrames[drop.id] = $0 }
                        .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .identity))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("reading your \(drop.kind.word) now")
                        .accessibilityIdentifier("nightQueued")
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: drops.map(\.id))
    }
}

struct NightBubble: View {
    let drop: Drop
    let reading: Bool

    @State private var picture: NightPicture?

    private var path: String? {
        drop.thumbnailPath ?? drop.cutoutPath ?? (drop.sourceKind == .image ? drop.mediaPaths.first : nil)
    }

    var body: some View {
        ZStack {
            if let picture {
                Image(decorative: picture.image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: drop.kind.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(.circle)
        .padding(4)
        .glassEffect(.regular, in: .circle)
        .overlay {
            if reading { NightBubbleRing() }
        }
        .task(id: path) {
            guard let path else { return }
            if let cached = NightImage.cached(NightImage.cacheKey(path, pixels: 168)) {
                picture = cached
                return
            }
            let loaded = await NightImage.load(path, toneKey: path, pixels: 168)
            withAnimation(.easeOut(duration: 0.2)) { picture = loaded }
        }
    }
}

struct NightBubbleRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Circle().strokeBorder(.tint.opacity(0.6), lineWidth: 2)
            } else {
                TimelineView(.animation) { context in
                    let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
                    Circle()
                        .inset(by: 1.25)
                        .trim(from: 0, to: 0.3)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(turn * 360))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct NightFlightLayer: View {
    let flight: NightFlightModel

    var body: some View {
        GeometryReader { proxy in
            if let drop = flight.drop {
                let origin = proxy.frame(in: .global).origin
                let spot = flight.lifted ? (flight.target.map { CGPoint(x: $0.midX, y: $0.midY) } ?? flight.from) : flight.from
                let scale = flight.popped ? max((flight.target?.width ?? 56) / 56, 1) : (flight.lifted ? 1.12 : 1)
                NightBubble(drop: drop, reading: false)
                    .shadow(color: .black.opacity(flight.lifted ? 0.35 : 0), radius: 16, y: 8)
                    .scaleEffect(scale)
                    .opacity(flight.popped ? 0 : 1)
                    .position(x: spot.x - origin.x, y: spot.y - origin.y)
                    .animation(.spring(response: 0.5, dampingFraction: 0.86), value: spot)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct NightTrack: ViewModifier {
    let isOn: Bool
    let report: (CGRect) -> Void

    func body(content: Content) -> some View {
        if isOn {
            content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { report($0) }
        } else {
            content
        }
    }
}

@MainActor
enum NightReplay {
    struct Link {
        let board: String?
        let drop: UUID
    }

    static let asked = Notification.Name("NightReplayAsked")
    static var pending: UUID?
    private static let playedKey = "NightPlayedDrops"

    static func link(in url: URL) -> Link? {
        guard url.scheme?.lowercased() == "resona", url.host()?.lowercased() == "drop",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let drop = items.first(where: { $0.name == "id" })?.value.flatMap(UUID.init(uuidString:))
        else { return nil }
        return Link(board: items.first { $0.name == "board" }?.value, drop: drop)
    }

    static func ask(_ drop: UUID) {
        pending = drop
        NotificationCenter.default.post(name: asked, object: nil)
    }

    static func unplayed(_ ids: [UUID]) -> [UUID] {
        let done = Set(UserDefaults.standard.stringArray(forKey: playedKey) ?? [])
        return ids.filter { !done.contains($0.uuidString) }
    }

    static func played(_ ids: [UUID]) {
        let list = (UserDefaults.standard.stringArray(forKey: playedKey) ?? []) + ids.map(\.uuidString)
        UserDefaults.standard.set(Array(list.suffix(200)), forKey: playedKey)
    }
}
