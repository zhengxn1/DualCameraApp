import AVFoundation
import Photos
import UIKit

// MARK: - Errors
enum DualCameraError: Error {
    case multiCamNotSupported
    case deviceNotFound
    case cannotAddInput
    case cannotAddOutput
    case connectionFailed

    var localizedDescription: String {
        switch self {
        case .multiCamNotSupported:
            return "此设备不支持多摄像头同时拍摄\n需要 iPhone XS / XR 或更新机型（iOS 13+）"
        case .deviceNotFound:
            return "未找到摄像头设备"
        case .cannotAddInput:
            return "无法添加摄像头输入"
        case .cannotAddOutput:
            return "无法添加摄像头输出"
        case .connectionFailed:
            return "摄像头连接建立失败"
        }
    }
}

// MARK: - DualCameraManager
class DualCameraManager: NSObject {

    // MARK: - Properties
    private(set) var multiCamSession: AVCaptureMultiCamSession?

    private var backCameraInput: AVCaptureDeviceInput?
    private var frontCameraInput: AVCaptureDeviceInput?

    private var backPhotoOutput: AVCapturePhotoOutput?
    private var frontPhotoOutput: AVCapturePhotoOutput?

    var backPreviewLayer: AVCaptureVideoPreviewLayer?
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?

    var isCapturing = false
    var onPhotoCaptured: ((UIImage?, UIImage?) -> Void)?
    var onError: ((String) -> Void)?

    private var capturedBackImage: UIImage?
    private var capturedFrontImage: UIImage?
    private var pendingCaptures = 0

    // MARK: - Permissions
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraStatus {
        case .authorized:
            requestPhotoLibraryPermission(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.requestPhotoLibraryPermission(completion: completion)
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            }
        default:
            DispatchQueue.main.async { completion(false) }
        }
    }

    private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    completion(status == .authorized || status == .limited)
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        }
    }

    // MARK: - Session Setup
    func setupSession() throws {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            throw DualCameraError.multiCamNotSupported
        }

        let session = AVCaptureMultiCamSession()
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // ── Back camera ──────────────────────────────────
        guard let backDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else { throw DualCameraError.deviceNotFound }

        let backInput = try AVCaptureDeviceInput(device: backDevice)
        guard session.canAddInput(backInput) else { throw DualCameraError.cannotAddInput }
        session.addInputWithNoConnections(backInput)
        self.backCameraInput = backInput

        // ── Front camera ─────────────────────────────────
        guard let frontDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ) else { throw DualCameraError.deviceNotFound }

        let frontInput = try AVCaptureDeviceInput(device: frontDevice)
        guard session.canAddInput(frontInput) else { throw DualCameraError.cannotAddInput }
        session.addInputWithNoConnections(frontInput)
        self.frontCameraInput = frontInput

        // ── Outputs ───────────────────────────────────────
        let backOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(backOutput) else { throw DualCameraError.cannotAddOutput }
        session.addOutputWithNoConnections(backOutput)
        self.backPhotoOutput = backOutput

        let frontOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(frontOutput) else { throw DualCameraError.cannotAddOutput }
        session.addOutputWithNoConnections(frontOutput)
        self.frontPhotoOutput = frontOutput

        // ── Ports ─────────────────────────────────────────
        guard let backPort = backInput.ports(
            for: .video,
            sourceDeviceType: backDevice.deviceType,
            sourceDevicePosition: .back
        ).first else { throw DualCameraError.connectionFailed }

        guard let frontPort = frontInput.ports(
            for: .video,
            sourceDeviceType: frontDevice.deviceType,
            sourceDevicePosition: .front
        ).first else { throw DualCameraError.connectionFailed }

        // ── Output Connections ────────────────────────────
        let backConn = AVCaptureConnection(inputPorts: [backPort], output: backOutput)
        guard session.canAddConnection(backConn) else { throw DualCameraError.connectionFailed }
        session.addConnection(backConn)

        let frontConn = AVCaptureConnection(inputPorts: [frontPort], output: frontOutput)
        guard session.canAddConnection(frontConn) else { throw DualCameraError.connectionFailed }
        session.addConnection(frontConn)

        // ── Preview Layers ────────────────────────────────
        let backPreview = AVCaptureVideoPreviewLayer()
        backPreview.videoGravity = .resizeAspectFill
        let backPreviewConn = AVCaptureConnection(inputPort: backPort, videoPreviewLayer: backPreview)
        if session.canAddConnection(backPreviewConn) {
            session.addConnection(backPreviewConn)
        }
        self.backPreviewLayer = backPreview

        let frontPreview = AVCaptureVideoPreviewLayer()
        frontPreview.videoGravity = .resizeAspectFill
        let frontPreviewConn = AVCaptureConnection(inputPort: frontPort, videoPreviewLayer: frontPreview)
        if session.canAddConnection(frontPreviewConn) {
            session.addConnection(frontPreviewConn)
        }
        self.frontPreviewLayer = frontPreview

        self.multiCamSession = session
    }

    // MARK: - Session Control
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.multiCamSession?.startRunning()
        }
    }

    func stopSession() {
        multiCamSession?.stopRunning()
    }

    // MARK: - Capture
    func capturePhotos() {
        guard !isCapturing else { return }
        isCapturing = true
        capturedBackImage = nil
        capturedFrontImage = nil
        pendingCaptures = 2

        let settings = AVCapturePhotoSettings()
        backPhotoOutput?.capturePhoto(with: settings, delegate: self)

        let frontSettings = AVCapturePhotoSettings()
        frontPhotoOutput?.capturePhoto(with: frontSettings, delegate: self)
    }

    // MARK: - Save
    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension DualCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            DispatchQueue.main.async { self.onError?(error.localizedDescription) }
            pendingCaptures -= 1
            if pendingCaptures == 0 { isCapturing = false }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        if output === backPhotoOutput {
            capturedBackImage = image
            saveToPhotoLibrary(image)
        } else if output === frontPhotoOutput {
            capturedFrontImage = image
            saveToPhotoLibrary(image)
        }

        pendingCaptures -= 1
        if pendingCaptures == 0 {
            isCapturing = false
            let back = capturedBackImage
            let front = capturedFrontImage
            DispatchQueue.main.async {
                self.onPhotoCaptured?(back, front)
            }
        }
    }
}
