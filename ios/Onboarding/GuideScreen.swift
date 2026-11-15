import SwiftUI
import UIKit

struct GuidePhone<Screen: View>: View {
    let width: CGFloat
    @ViewBuilder var screen: Screen

    var body: some View {
        let height = width * 2.05
        let corner = width * 0.17
        ZStack(alignment: .top) {
            screen
                .frame(width: width - 12, height: height - 12)
                .clipShape(.rect(cornerRadius: corner - 6, style: .continuous))
            Capsule()
                .fill(.black)
                .frame(width: width * 0.3, height: width * 0.09)
                .padding(.top, width * 0.035)
        }
        .padding(6)
        .background(Color(white: 0.12), in: .rect(cornerRadius: corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.6), radius: 30, y: 18)
        .environment(\.colorScheme, .dark)
    }
}

/// What the phone shows. Every app here is a sketch of the real thing, made of SwiftUI shapes and the guide's
/// photos. `inset` lifts whatever sits at the bottom of a screen above the stage's fade.
struct GuideScreen: View {
    let phase: GuidePhase
    let shared: Bool
    let inset: CGFloat

    var body: some View {
        ZStack {
            switch phase {
            case .hidden, .shareApp, .shareSheet, .sharedSong:
                SongAppScreen(sheetUp: phase == .shareSheet, inset: inset)
                    .transition(.opacity)
            case .sharedPlace:
                PlaceAppScreen()
                    .transition(.opacity)
            case .sharedClip:
                ClipAppScreen(inset: inset)
                    .transition(.opacity)
            default:
                BoardScreen(shared: shared, byVibe: phase.byVibe)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
    }
}

private struct ShareButton: View {
    var body: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .glassEffect(.regular.tint(.black.opacity(0.2)), in: .circle)
            .guideTarget(.share)
    }
}

private struct SongAppScreen: View {
    let sheetUp: Bool
    let inset: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.78, green: 0.38, blue: 0.24), Color(red: 0.25, green: 0.11, blue: 0.08), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chevron.down")
                    Spacer()
                    Text("now playing")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    ShareButton()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 36)
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image("guide-song")
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                Text("san francisco")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white).frame(width: 64, height: 3)
                    }
                    .padding(.horizontal, 8)
                HStack(spacing: 30) {
                    Image(systemName: "backward.fill")
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 40))
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 18))
                .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            if sheetUp {
                MiniShareSheet(inset: inset)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: sheetUp)
    }
}

private struct MiniShareSheet: View {
    let inset: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 34, height: 4)
                .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Image("guide-song")
                    .resizable()
                    .frame(width: 34, height: 34)
                    .clipShape(.rect(cornerRadius: 7, style: .continuous))
                Text("san francisco")
                    .font(.system(size: 14, weight: .semibold))
            }
            Divider()
            HStack(alignment: .top, spacing: 0) {
                appIcon("messages", symbol: "message.fill", color: .green)
                appIcon("mail", symbol: "envelope.fill", color: .blue)
                appIcon("notes", symbol: "note.text", color: .yellow)
                VStack(spacing: 5) {
                    OurAppIcon()
                        .frame(width: 46, height: 46)
                        .guideTarget(.ourApp)
                    Text(Onboarding.appName)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .padding(.bottom, inset)
        .background(Color(.secondarySystemBackground), in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous))
    }

    private func appIcon(_ name: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(color.gradient, in: .rect(cornerRadius: 11, style: .continuous))
            Text(name)
                .font(.system(size: 10, weight: .medium))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OurAppIcon: View {
    private static let icon: UIImage? = {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last
        else { return nil }
        return UIImage(named: name)
    }()

    var body: some View {
        Group {
            if let icon = Self.icon {
                Image(uiImage: icon)
                    .resizable()
            } else {
                Image(systemName: "pin.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.onboardingTint)
            }
        }
        .clipShape(.rect(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.onboardingTint, lineWidth: 2)
                .padding(-3)
        }
    }
}

private struct PlaceAppScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 176)
                .overlay {
                    Image("guide-place")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    ShareButton().padding(.top, 36).padding(.trailing, 16)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text("tartine bakery")
                    .font(.system(size: 20, weight: .bold))
                Text("bakery in the mission")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                    Text("4.6")
                        .padding(.leading, 4)
                }
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                HStack(spacing: 8) {
                    Label("directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Color.blue, in: .capsule)
                    Label("call", systemImage: "phone.fill")
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Color.blue.opacity(0.15), in: .capsule)
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            MapTile()
                .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .background(Color(.systemBackground))
    }
}

/// A few streets and a pin, so the place screen reads as a maps app.
private struct MapTile: View {
    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.15, blue: 0.17)
            Path { path in
                for column in 0..<6 {
                    let x = CGFloat(column) * 54 + 8
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + 26, y: 220))
                }
                for row in 0..<5 {
                    let y = CGFloat(row) * 44 + 14
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: 320, y: y - 16))
                }
            }
            .stroke(.white.opacity(0.1), lineWidth: 5)
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white, .red)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
        .frame(height: 150)
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
    }
}

private struct ClipAppScreen: View {
    let inset: CGFloat

    var body: some View {
        ZStack {
            Color.clear
                .overlay {
                    Image("guide-clip")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
            LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .padding(.bottom, inset)
            Color.black.opacity(0.6)
                .frame(height: inset)
                .frame(maxHeight: .infinity, alignment: .bottom)
            VStack {
                HStack(spacing: 16) {
                    Text("following").opacity(0.7)
                    Text("for you").fontWeight(.bold)
                }
                .font(.system(size: 13))
                .padding(.top, 40)
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("@graacciiee")
                            .font(.system(size: 13, weight: .bold))
                        Text("dolores park on a sunny day")
                            .font(.system(size: 12))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 16)
                    VStack(spacing: 14) {
                        rail("heart.fill", "48k")
                        rail("ellipsis.bubble.fill", "312")
                        rail("arrowshape.turn.up.right.fill", "share")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24 + inset)
            }
            .foregroundStyle(.white)
        }
    }

    private func rail(_ symbol: String, _ count: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 20))
            Text(count)
                .font(.system(size: 10, weight: .semibold))
        }
    }
}

private struct BoardScreen: View {
    let shared: Bool
    let byVibe: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if byVibe {
                Color(red: 0.165, green: 0.137, blue: 0.114)
                Image("Kit/cork-speckle")
                    .resizable(resizingMode: .tile)
                    .foregroundStyle(.white.opacity(0.06))
            } else {
                NightBackdrop(isLiving: false)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text(shared ? Onboarding.demoBoardName : "my board")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.interpolate)
                    Spacer()
                    HStack(spacing: -6) {
                        ForEach(shared ? [GuideSample.Person.you, .maya, .sam, .alex] : [.you], id: \.self) { person in
                            GuideAvatar(person: person, size: 22)
                                .overlay(Circle().stroke(.black, lineWidth: 1.5))
                        }
                    }
                }
                if shared && !byVibe {
                    HStack(spacing: 0) {
                        Text("everyone")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(.white.opacity(0.18), in: .capsule)
                        Text("mine")
                            .padding(.horizontal, 12)
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12))
                    .padding(3)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.opacity)
                }
            }
            .padding(.top, 38)
            .padding(.horizontal, 14)
        }
        .animation(.smooth(duration: 0.3), value: byVibe)
    }
}
