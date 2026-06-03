import AVFoundation
import Combine
import SwiftUI
import UIKit

final class LiveCameraScannerViewModel: NSObject, ObservableObject {
    @Published var previewImage: UIImage?
    @Published var isRunning = false
    @Published var authorizationMessage: String?

    let session = AVCaptureSession()
    var onFrame: ((UIImage) -> Void)?

    private let queue = DispatchQueue(label: "gemstone.live.camera")
    private var lastAnalysis = Date.distantPast
    private let output = AVCaptureVideoDataOutput()

    override init() {
        super.init()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.authorizationMessage = "カメラの使用が許可されていません。設定から許可してください。"
                    }
                }
            }
        default:
            authorizationMessage = "カメラの使用が許可されていません。設定から許可してください。"
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async {
                        self.authorizationMessage = "背面カメラを起動できませんでした。"
                    }
                    self.session.commitConfiguration()
                    return
                }
                self.session.addInput(input)

                self.output.alwaysDiscardsLateVideoFrames = true
                self.output.setSampleBufferDelegate(self, queue: self.queue)
                self.output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                self.output.connection(with: .video)?.videoOrientation = .portrait
                self.session.commitConfiguration()
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = true
                self.authorizationMessage = nil
            }
        }
    }
}

extension LiveCameraScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) > 1.4 else { return }
        lastAnalysis = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        DispatchQueue.main.async { [weak self] in
            self?.previewImage = image
            self?.onFrame?(image)
        }
    }
}

struct LiveCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
