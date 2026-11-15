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
    @State private var lastPhoto: CameraShot?
    @State private var dropped = 0
    @State private var capturing = 0
    @State private var shots = 0
    @State private var flash = 0.0
    @State private var justDropped = false
    @State private var viewfinderFrame: CGRect = .zero
    @State private var flightsFrame: CGRect = .zero
    @State private var thumbnailFrame: CGRect = .zero
    @State private var focus: CGPoint?
    @State private var focusTaps = 0
    @State private var isPinching = false

    private static let space = "camera"
    private static let zoomPresets: [CGFloat] = [1, 2]

    private enum Status {
        case idle, dropping, dropped
    }

    private var status: Status {
        if capturing > 0 || !flights.isEmpty { return .dropping }
        return justDropped ? .dropped : .idle
    }

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
                GlassEffectContainer {
                    closeButton
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
            }
        }
        .coordinateSpace(.named(Self.space))
        .animation(.easeOut(duration: 0.25), value: camera.access)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: shots)
        .sensoryFeedback(.success, trigger: dropped)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, camera.access != .allowed else { return }
            Task { await camera.start() }
        }
        .onCameraCaptureEvent { event in
            if event.phase == .ended { shoot() }
        }
        .task(id: dropped) {
            guard dropped > 0 else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.3)) { justDropped = false }
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
                .blur(radius: camera.isSwitching ? 24 : 0)
                .animation(.easeOut(duration: 0.2), value: camera.isSwitching)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { viewfinderFrame = $0 }
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
                .ignoresSafeArea()
            scrim
            ZStack {
                ForEach(flights) { shot in
                    CaptureFlight(
                        shot: shot,
                        start: viewfinderFrame.offsetBy(dx: -flightsFrame.minX, dy: -flightsFrame.minY),
                        end: thumbnailFrame.offsetBy(dx: -flightsFrame.minX, dy: -flightsFrame.minY),
                        reduceMotion: reduceMotion,
                        onLand: { land(shot) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { flightsFrame = $0 }
            .ignoresSafeArea()
            if let focus {
                FocusRing()
                    .id(focusTaps)
                    .position(focus)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            Color.white
                .opacity(flash)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            controls
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
            LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 300)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 0) {
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
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                statusCapsule
                    .frame(height: 36)
                    .padding(.bottom, 16)

                zoomCapsule
                    .padding(.bottom, 20)

                HStack(spacing: 0) {
                    HStack(spacing: 10) {
                        lastPhotoButton
                        Text(boardName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .opacity(status == .idle ? 1 : 0)
                            .animation(.smooth(duration: 0.25), value: status)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: shoot) {
                        Color.clear
                    }
                    .buttonStyle(ShutterButtonStyle())
                    .accessibilityLabel("take a photo")
                    .accessibilityIdentifier("cameraShutter")
                    .padding(.horizontal, 12)
                    Button {
                        Task { await camera.flip() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.rotate, value: camera.position)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(camera.position == .back ? "switch to the front camera" : "switch to the back camera")
                    .accessibilityIdentifier("cameraFlip")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
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
        .accessibilityLabel("close camera")
        .accessibilityIdentifier("cameraClose")
    }

    @ViewBuilder
    private var statusCapsule: some View {
        if status != .idle {
            Text(status == .dropping ? "dropping it in \(boardName)." : "dropped it in \(boardName).")
                .font(.subheadline.weight(.semibold))
                .contentTransition(.opacity)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .glassEffect(.regular, in: .capsule)
                .animation(.smooth(duration: 0.25), value: status)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .accessibilityIdentifier("cameraStatus")
        }
    }

    private var zoomCapsule: some View {
        HStack(spacing: 2) {
            ForEach(Self.zoomPresets, id: \.self) { preset in
                let isSelected = Self.selectedPreset(for: camera.zoom, in: Self.zoomPresets) == preset
                Button {
                    withAnimation(.snappy(duration: 0.25)) { camera.setZoom(preset) }
                } label: {
                    Text(isSelected ? Self.zoomWords(camera.zoom) : Self.zoomWords(preset).replacingOccurrences(of: "×", with: ""))
                        .font(.system(size: isSelected ? 13 : 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(isSelected ? Color.yellow : .white)
                        .contentTransition(.numericText(value: camera.zoom))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.black.opacity(isSelected ? 0.35 : 0)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("zoom to \(Self.zoomWords(preset))")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("cameraZoom-\(Int(preset))")
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .animation(.snappy(duration: 0.2), value: camera.zoom)
    }

    private var lastPhotoButton: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                if let lastPhoto {
                    Image(uiImage: lastPhoto.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: CaptureFlight.landedCorner, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: CaptureFlight.landedCorner, style: .continuous)
                                .strokeBorder(.white, lineWidth: CaptureFlight.landedBorder)
                        }
                } else {
                    RoundedRectangle(cornerRadius: CaptureFlight.landedCorner, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                }
            }
            .overlay(alignment: .topTrailing) {
                if dropped > 0 {
                    Text("\(dropped)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.black)
                        .contentTransition(.numericText(value: Double(dropped)))
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(.white))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(lastPhoto == nil)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { thumbnailFrame = $0 }
        .keyframeAnimator(initialValue: 1.0, trigger: dropped) { content, scale in
            content.scaleEffect(reduceMotion ? 1 : scale)
        } keyframes: { _ in
            SpringKeyframe(1.08, duration: 0.12, spring: .snappy(duration: 0.3))
            SpringKeyframe(1, duration: 0.3, spring: .snappy(duration: 0.3))
        }
        .accessibilityLabel(dropped == 1 ? "you dropped 1 photo in \(boardName). tap to see the board." : "you dropped \(dropped) photos in \(boardName). tap to see the board.")
        .accessibilityIdentifier("cameraLastPhoto")
    }

    static func selectedPreset(for zoom: CGFloat, in presets: [CGFloat]) -> CGFloat {
        presets.last { zoom >= $0 - 0.05 } ?? presets[0]
    }

    static func zoomWords(_ zoom: CGFloat) -> String {
        let rounded = (zoom * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))×" : String(format: "%.1f×", rounded)
    }

    private func shoot() {
        guard camera.access == .allowed else { return }
        shots += 1
        capturing += 1
        flash = reduceMotion ? 0.3 : 0.5
        withAnimation(.easeOut(duration: 0.18)) { flash = 0 }
        Task {
            let shot = await camera.capture()
            if let shot {
                if CameraDebug.mayDrop {
                    CameraInbox.drop(shot.data)
                    sync.wake(in: context)
                } else {
                    Logger.camera.info("a sample photo stays off the board because the board isn't offline")
                }
                flights.append(shot)
            }
            capturing -= 1
        }
    }

    private func land(_ shot: CameraShot) {
        var landing = Transaction()
        landing.disablesAnimations = !reduceMotion
        if reduceMotion { landing.animation = .easeOut(duration: 0.2) }
        withTransaction(landing) {
            lastPhoto = shot
            flights.removeAll { $0.id == shot.id }
            justDropped = true
        }
        dropped += 1
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
