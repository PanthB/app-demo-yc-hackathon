import AVKit
import os
import PhotosUI
import SwiftUI

struct DropCamera: View {
    @Environment(BoardSync.self) private var sync
    @Environment(BoardsStore.self) private var boards
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camera = CameraModel()
    @State private var flights: [CameraShot] = []
    @State private var landed: [CameraShot] = []
    @State private var shots = 0
    @State private var landings = 0
    @State private var flash = 0.0
    @State private var justDropped = false
    @State private var screen: CGRect = .zero
    @State private var target: CGPoint = .zero
    @State private var focus: CGPoint?
    @State private var focusTaps = 0
    @State private var isPinching = false

    private var boardName: String { boards.currentBoardName }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera.access {
            case .allowed:
                viewfinder
            case .checking:
                EmptyView()
            case .notAsked, .denied, .unavailable:
                CameraBackdrop()
                CameraAccessView(
                    access: camera.access,
                    boardName: boardName,
                    onAsk: { Task { await camera.askForAccess() } },
                    onPicked: { items in Task { await keep(items) } },
                    onClose: { dismiss() }
                )
                .transition(.opacity)
                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
            }
        }
        .animation(.easeOut(duration: 0.25), value: camera.access)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screen = $0 }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: shots)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: landings)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, camera.access != .allowed else { return }
            Task { await camera.start() }
        }
        .onCameraCaptureEvent { event in
            if event.phase == .ended { shoot() }
        }
        .task(id: landings) {
            guard landings > 0 else { return }
            justDropped = true
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            justDropped = false
        }
        #if DEBUG
        .task {
            guard let delay = CameraDebug.autoShootDelay else { return }
            try? await Task.sleep(for: .seconds(delay))
            for shot in 0..<CameraDebug.autoShots {
                if shot > 0 { try? await Task.sleep(for: .seconds(2.2)) }
                shoot()
            }
        }
        #endif
    }

    private var viewfinder: some View {
        ZStack {
            preview
                .ignoresSafeArea()
                .blur(radius: camera.isSwitching ? 24 : 0)
                .animation(.easeOut(duration: 0.2), value: camera.isSwitching)
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            if !isPinching {
                                isPinching = true
                                camera.beginPinch()
                            }
                            camera.pinch(value.magnification)
                        }
                        .onEnded { _ in isPinching = false }
                )
            if let focus {
                FocusRing()
                    .id(focusTaps)
                    .position(focus)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            scrim
            controls
            Color.white
                .opacity(flash)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            ForEach(flights) { shot in
                CaptureFlight(
                    shot: shot,
                    frame: CGRect(origin: .zero, size: screen.size),
                    target: CGPoint(x: target.x - screen.minX, y: target.y - screen.minY),
                    reduceMotion: reduceMotion,
                    onLand: { land(shot) },
                    onDone: { flights.removeAll { $0.id == shot.id } }
                )
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var preview: some View {
        #if DEBUG
        if CameraDebug.usesStill {
            GeometryReader { proxy in
                if let still = camera.still {
                    Image(uiImage: still)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(camera.zoom)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { point in showFocus(at: point) }
                }
            }
            .accessibilityIdentifier("cameraStill")
        } else {
            livePreview
        }
        #else
        livePreview
        #endif
    }

    private var livePreview: some View {
        CameraPreview(session: camera.session) { point, devicePoint in
            camera.focus(at: devicePoint)
            showFocus(at: point)
        }
    }

    private var scrim: some View {
        VStack {
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .frame(height: 280)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 12) {
                HStack {
                    closeButton
                    Spacer()
                    if camera.hasFlash {
                        Button {
                            camera.flash = camera.flash.next
                        } label: {
                            Image(systemName: camera.flash.symbol)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(camera.flash.words)
                        .accessibilityIdentifier("cameraFlash")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            chip
                .padding(.bottom, 22)

            HStack {
                zoomButton
                    .frame(maxWidth: .infinity)
                Button(action: shoot) {
                    Color.clear
                }
                .buttonStyle(ShutterButtonStyle())
                .accessibilityLabel("take a photo")
                .accessibilityIdentifier("cameraShutter")
                Button {
                    Task { await camera.flip() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .symbolEffect(.rotate, value: camera.position)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(camera.position == .back ? "switch to the front camera" : "switch to the back camera")
                .accessibilityIdentifier("cameraFlip")
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("close the camera")
        .accessibilityIdentifier("cameraClose")
    }

    private var zoomButton: some View {
        Button {
            camera.setZoom(camera.zoom < 1.95 ? 2 : 1)
        } label: {
            Text(Self.zoomWords(camera.zoom))
                .font(.footnote.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText(value: camera.zoom))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .animation(.snappy(duration: 0.2), value: camera.zoom)
        .accessibilityLabel("zoom is \(Self.zoomWords(camera.zoom))")
        .accessibilityIdentifier("cameraZoom")
    }

    static func zoomWords(_ zoom: CGFloat) -> String {
        let rounded = (zoom * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))×" : String(format: "%.1f×", rounded)
    }

    private var chip: some View {
        HStack(spacing: 10) {
            LandedStack(shots: landed, reduceMotion: reduceMotion)
                .frame(width: 30, height: 30)
                .onGeometryChange(for: CGPoint.self) { proxy in
                    let frame = proxy.frame(in: .global)
                    return CGPoint(x: frame.midX, y: frame.midY)
                } action: { target = $0 }
            Text(justDropped ? "dropped it into \(boardName)." : "dropping into \(boardName).")
                .font(.subheadline.weight(.semibold))
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: justDropped)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .keyframeAnimator(initialValue: 1.0, trigger: landings) { content, scale in
            content.scaleEffect(reduceMotion ? 1 : scale)
        } keyframes: { _ in
            SpringKeyframe(1.08, duration: 0.12, spring: .snappy)
            SpringKeyframe(1, duration: 0.45, spring: .init(duration: 0.45, bounce: 0.45))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cameraBoardChip")
    }

    private func shoot() {
        guard camera.access == .allowed else { return }
        shots += 1
        if reduceMotion {
            flash = 0.35
            withAnimation(.easeOut(duration: 0.3)) { flash = 0 }
        } else {
            withAnimation(.linear(duration: 0.04)) { flash = 0.85 } completion: {
                withAnimation(.easeOut(duration: 0.28)) { flash = 0 }
            }
        }
        Task {
            guard let shot = await camera.capture() else { return }
            CameraInbox.drop(shot.data)
            sync.wake(in: context)
            flights.append(shot)
        }
    }

    private func land(_ shot: CameraShot) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.35)) {
            landed.append(shot)
            if landed.count > 3 { landed.removeFirst(landed.count - 3) }
        }
        landings += 1
    }

    private func showFocus(at point: CGPoint) {
        focusTaps += 1
        withAnimation(.easeOut(duration: 0.15)) { focus = point }
        let tap = focusTaps
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard tap == focusTaps else { return }
            withAnimation(.easeOut(duration: 0.3)) { focus = nil }
        }
    }

    private func keep(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                CameraInbox.drop(data)
            } catch {
                Logger.camera.error("a picked photo couldn't be loaded: \(String(describing: error), privacy: .public)")
            }
        }
        sync.wake(in: context)
        dismiss()
    }
}

private struct FocusRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(.white, lineWidth: 1.5)
            .frame(width: 76, height: 76)
            .scaleEffect(settled || reduceMotion ? 1 : 1.25)
            .opacity(settled ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) { settled = true }
            }
            .allowsHitTesting(false)
    }
}

private struct LandedStack: View {
    let shots: [CameraShot]
    let reduceMotion: Bool

    private static let tilts: [Double] = [-9, 7, -2]

    var body: some View {
        ZStack {
            if shots.isEmpty {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .transition(.opacity)
            }
            ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                Image(uiImage: shot.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(.white, lineWidth: 1.5)
                    }
                    .rotationEffect(.degrees(Self.tilts[(shots.count - 1 - index) % Self.tilts.count] * (index == shots.count - 1 ? 0.3 : 1)))
                    .offset(x: CGFloat(index - shots.count + 1) * 5)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.4).combined(with: .opacity))
            }
        }
    }
}
