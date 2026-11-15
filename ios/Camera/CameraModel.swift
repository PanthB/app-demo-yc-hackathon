import AVFoundation
import Observation
import os
import UIKit

extension Logger {
    static let camera = Logger(subsystem: subsystem, category: "camera")
}

enum CameraAccess: Equatable {
    case checking, notAsked, allowed, denied, unavailable
}

enum CameraFlash: CaseIterable {
    case off, auto, on

    var next: CameraFlash {
        switch self {
        case .off: .auto
        case .auto: .on
        case .on: .off
        }
    }

    var symbol: String {
        switch self {
        case .off: "bolt.slash.fill"
        case .auto: "bolt.badge.automatic.fill"
        case .on: "bolt.fill"
        }
    }

    var words: String {
        switch self {
        case .off: "the flash is off."
        case .auto: "the flash comes on when it's dark."
        case .on: "the flash is on."
        }
    }

    var mode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .auto: .auto
        case .on: .on
        }
    }
}

struct CameraShot: Identifiable {
    let id = UUID()
    let data: Data
    let image: UIImage
}

@MainActor
@Observable
final class CameraModel {
    private(set) var access: CameraAccess = .checking
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var zoom: CGFloat = 1
    private(set) var hasFlash = false
    private(set) var isSwitching = false
    private(set) var still: UIImage?
    var flash: CameraFlash = .off

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.panthb.appdemo.camera")
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let controls = CameraControls()
    @ObservationIgnored private var input: AVCaptureDeviceInput?
    @ObservationIgnored private var captures: [Int64: PhotoCapture] = [:]
    @ObservationIgnored private var zoomAtPinchStart: CGFloat = 1
    @ObservationIgnored private var stillIndex = 0

    static let maxZoom: CGFloat = 8

    var device: AVCaptureDevice? { input?.device }

    func start() async {
        #if DEBUG
        if let forced = CameraDebug.forcedAccess, access == .checking {
            access = forced
            return
        }
        if CameraDebug.usesStill {
            if still == nil { still = CameraDebug.still(stillIndex) }
            hasFlash = true
            access = .allowed
            return
        }
        #endif
        guard Self.camera(at: position) != nil else {
            Logger.camera.info("this device has no camera to use")
            access = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await run()
        case .notDetermined:
            access = .notAsked
        default:
            access = .denied
        }
    }

    func askForAccess() async {
        #if DEBUG
        if CameraDebug.usesStill {
            access = .checking
            await start()
            return
        }
        #endif
        if await AVCaptureDevice.requestAccess(for: .video) {
            await run()
        } else {
            Logger.camera.info("the camera wasn't allowed")
            access = .denied
        }
    }

    func stop() {
        let session = session
        queue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    private func run() async {
        if input == nil {
            guard await attach(position) else {
                access = .unavailable
                return
            }
        }
        let session = session
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                if !session.isRunning { session.startRunning() }
                done.resume()
            }
        }
        access = .allowed
    }

    private func attach(_ position: AVCaptureDevice.Position) async -> Bool {
        guard let camera = Self.camera(at: position) else { return false }
        let session = session, output = output, controls = controls, queue = queue
        let old = input
        let attached: AVCaptureDeviceInput? = await withCheckedContinuation { done in
            queue.async {
                do {
                    let new = try AVCaptureDeviceInput(device: camera)
                    session.beginConfiguration()
                    defer { session.commitConfiguration() }
                    session.sessionPreset = .photo
                    if let old { session.removeInput(old) }
                    guard session.canAddInput(new) else {
                        if let old, session.canAddInput(old) { session.addInput(old) }
                        Logger.camera.error("the session wouldn't take the \(position == .front ? "front" : "back", privacy: .public) camera")
                        done.resume(returning: nil)
                        return
                    }
                    session.addInput(new)
                    if !session.outputs.contains(output), session.canAddOutput(output) {
                        session.addOutput(output)
                        output.maxPhotoQualityPrioritization = .balanced
                    }
                    for control in session.controls { session.removeControl(control) }
                    if session.supportsControls {
                        let slider = AVCaptureSystemZoomSlider(device: camera) { factor in
                            Task { @MainActor in controls.onZoom?(factor) }
                        }
                        if session.canAddControl(slider) { session.addControl(slider) }
                        session.setControlsDelegate(controls, queue: queue)
                    }
                    done.resume(returning: new)
                } catch {
                    Logger.camera.error("couldn't open the camera: \(String(describing: error), privacy: .public)")
                    done.resume(returning: nil)
                }
            }
        }
        guard let attached else { return false }
        input = attached
        controls.onZoom = { [weak self] factor in self?.zoom = factor }
        zoom = attached.device.videoZoomFactor
        hasFlash = attached.device.hasFlash
        return true
    }

    func flip() async {
        guard !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }
        let next: AVCaptureDevice.Position = position == .back ? .front : .back
        #if DEBUG
        if CameraDebug.usesStill {
            try? await Task.sleep(for: .milliseconds(180))
            position = next
            advanceStill()
            return
        }
        #endif
        if await attach(next) { position = next }
    }

    func focus(at point: CGPoint) {
        guard let device, device.isFocusPointOfInterestSupported || device.isExposurePointOfInterestSupported else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            Logger.camera.error("couldn't focus: \(String(describing: error), privacy: .public)")
        }
    }

    func beginPinch() {
        zoomAtPinchStart = zoom
    }

    func pinch(_ magnification: CGFloat) {
        setZoom(zoomAtPinchStart * magnification)
    }

    func setZoom(_ factor: CGFloat) {
        guard let device else {
            zoom = Self.clamp(factor, from: 1, to: 4)
            return
        }
        let clamped = Self.clamp(factor, from: device.minAvailableVideoZoomFactor, to: min(device.maxAvailableVideoZoomFactor, Self.maxZoom))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            zoom = clamped
        } catch {
            Logger.camera.error("couldn't zoom: \(String(describing: error), privacy: .public)")
        }
    }

    nonisolated static func clamp(_ value: CGFloat, from low: CGFloat, to high: CGFloat) -> CGFloat {
        min(max(value, low), max(low, high))
    }

    func capture() async -> CameraShot? {
        #if DEBUG
        if CameraDebug.usesStill, let still {
            defer { advanceStill() }
            guard let data = still.jpegData(compressionQuality: 0.9) else { return nil }
            return CameraShot(data: data, image: still)
        }
        #endif
        guard access == .allowed else { return nil }
        let settings = output.availablePhotoCodecTypes.contains(.jpeg)
            ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            : AVCapturePhotoSettings()
        if hasFlash, output.supportedFlashModes.contains(flash.mode) {
            settings.flashMode = flash.mode
        }
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        let id = settings.uniqueID
        let output = output
        let data: Data? = await withCheckedContinuation { done in
            let capture = PhotoCapture { data in
                done.resume(returning: data)
            }
            captures[id] = capture
            queue.async {
                output.capturePhoto(with: settings, delegate: capture)
            }
        }
        captures[id] = nil
        guard let data, let image = UIImage(data: data) else {
            Logger.camera.error("the photo came back empty")
            return nil
        }
        return CameraShot(data: data, image: image)
    }

    private func advanceStill() {
        #if DEBUG
        stillIndex += 1
        still = CameraDebug.still(stillIndex)
        #endif
    }

    private nonisolated static func camera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }
}

private final class PhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {
    private let done: (Data?) -> Void

    init(done: @escaping (Data?) -> Void) {
        self.done = done
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Logger.camera.error("taking the photo failed: \(String(describing: error), privacy: .public)")
        }
        done(error == nil ? photo.fileDataRepresentation() : nil)
    }
}

private final class CameraControls: NSObject, AVCaptureSessionControlsDelegate {
    var onZoom: ((CGFloat) -> Void)?

    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {}
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {}
}
