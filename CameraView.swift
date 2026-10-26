//
//  CameraView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera Preview using AVCaptureSession
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var classificationResult: String?
    @Binding var isImageCaptured: Bool
    @Binding var captureTrigger: Bool
    var isLiveDetectionEnabled: Bool = true

    @ObservedObject var visionClassifier: VisionClassifier
    let targetObject: String
    let onObjectFound: (Bool, Double, String) -> Void

    class CameraViewController: UIViewController {
        var captureSession: AVCaptureSession!
        var stillImageOutput: AVCapturePhotoOutput!
        var videoDataOutput: AVCaptureVideoDataOutput!
        var previewLayer: AVCaptureVideoPreviewLayer!
        private let videoQueue = DispatchQueue(label: "sbog.camera.video", qos: .userInitiated)
        private let liveDetector = LiveCameraObjectDetector()
        private let detectionOverlay = CameraDetectionOverlayView()

        var capturedImage: Binding<UIImage?>
        var classificationResult: Binding<String?>
        var isImageCaptured: Binding<Bool>

        var visionClassifier: VisionClassifier

        var targetObject: String
        var onObjectFound: (Bool, Double, String) -> Void
        var isLiveDetectionEnabled = true

        init(
            capturedImage: Binding<UIImage?>,
            classificationResult: Binding<String?>,
            isImageCaptured: Binding<Bool>,
            visionClassifier: VisionClassifier,
            targetObject: String,
            onObjectFound: @escaping (Bool, Double, String) -> Void
        ) {
            self.capturedImage = capturedImage
            self.classificationResult = classificationResult
            self.isImageCaptured = isImageCaptured
            self.visionClassifier = visionClassifier
            self.targetObject = targetObject
            self.onObjectFound = onObjectFound
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            liveDetector.onDetections = { [weak self] detections in
                guard let self, self.isLiveDetectionEnabled, let previewLayer = self.previewLayer else {
                    self?.detectionOverlay.boxes = []
                    return
                }
                self.detectionOverlay.boxes = CameraBoundingBoxConverter.annotations(
                    from: detections,
                    previewLayer: previewLayer,
                    targetObject: self.targetObject
                )
            }
            setupCamera()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if captureSession != nil, !captureSession.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.startRunning()
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if captureSession != nil, captureSession.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.stopRunning()
                }
            }
        }

        func setupCamera() {
            captureSession = AVCaptureSession()
            captureSession.sessionPreset = .high

            guard let backCamera = AVCaptureDevice.default(for: .video) else {
                print("❌ Unable to access back camera!")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: backCamera)
                stillImageOutput = AVCapturePhotoOutput()

                videoDataOutput = AVCaptureVideoDataOutput()
                videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)

                if captureSession.canAddInput(input),
                   captureSession.canAddOutput(stillImageOutput),
                   captureSession.canAddOutput(videoDataOutput) {
                    captureSession.addInput(input)
                    captureSession.addOutput(stillImageOutput)
                    captureSession.addOutput(videoDataOutput)
                    if let connection = videoDataOutput.connection(with: .video) {
                        connection.videoOrientation = .portrait
                    }
                    setupLivePreview()
                }
            } catch {
                print("❌ Error setting up camera: \(error.localizedDescription)")
            }
        }

        func setupLivePreview() {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait

            view.layer.addSublayer(previewLayer)
            detectionOverlay.frame = view.bounds
            view.addSubview(detectionOverlay)

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.previewLayer.frame = self.view.bounds
                }
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
            detectionOverlay.frame = view.bounds
            if !detectionOverlay.boxes.isEmpty {
                detectionOverlay.setNeedsDisplay()
            }
        }

        @objc func capturePhoto() {
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            stillImageOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController(
            capturedImage: $capturedImage,
            classificationResult: $classificationResult,
            isImageCaptured: $isImageCaptured,
            visionClassifier: visionClassifier,
            targetObject: targetObject,
            onObjectFound: onObjectFound
        )
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.targetObject = targetObject
        uiViewController.isLiveDetectionEnabled = isLiveDetectionEnabled && !isImageCaptured
        if !uiViewController.isLiveDetectionEnabled {
            uiViewController.detectionOverlayPublic.boxes = []
            uiViewController.liveDetectorPublic.reset()
        }
        if captureTrigger {
            uiViewController.capturePhoto()
            DispatchQueue.main.async {
                self.captureTrigger = false
            }
        }
    }
}

extension CameraPreviewView.CameraViewController {
    var detectionOverlayPublic: CameraDetectionOverlayView { detectionOverlay }
    var liveDetectorPublic: LiveCameraObjectDetector { liveDetector }
}

// MARK: - Live video frames
extension CameraPreviewView.CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isLiveDetectionEnabled, !isImageCaptured.wrappedValue else { return }
        liveDetector.process(sampleBuffer: sampleBuffer, targetObject: targetObject)
    }
}

// MARK: - Capture Delegate
extension CameraPreviewView.CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        if let error = error {
            print("❌ Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        capturedImage.wrappedValue = image
        isImageCaptured.wrappedValue = true
        detectionOverlay.boxes = []
        liveDetector.reset()

        visionClassifier.classifyImage(image, targetObject: targetObject) { found, confidence, topText in
            DispatchQueue.main.async {
                if found {
                    self.classificationResult.wrappedValue = String(
                        format: NSLocalizedString("Found %@! ✅\n%@", comment: ""),
                        self.targetObject,
                        topText
                    )
                    self.onObjectFound(true, confidence, topText)
                } else {
                    self.classificationResult.wrappedValue = "❌ \(topText)"
                    self.onObjectFound(false, confidence, topText)
                }
            }
        }
    }
}

// MARK: - UIImagePickerController Wrapper
struct CameraViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var classificationResult: String?
    @Binding var isImageCaptured: Bool

    @ObservedObject var visionClassifier: VisionClassifier
    let targetObject: String
    let onObjectFound: (Bool, Double, String) -> Void

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding var capturedImage: UIImage?
        @Binding var classificationResult: String?
        @Binding var isImageCaptured: Bool

        let visionClassifier: VisionClassifier
        let targetObject: String
        let onObjectFound: (Bool, Double, String) -> Void

        init(
            capturedImage: Binding<UIImage?>,
            classificationResult: Binding<String?>,
            isImageCaptured: Binding<Bool>,
            visionClassifier: VisionClassifier,
            targetObject: String,
            onObjectFound: @escaping (Bool, Double, String) -> Void
        ) {
            _capturedImage = capturedImage
            _classificationResult = classificationResult
            _isImageCaptured = isImageCaptured
            self.visionClassifier = visionClassifier
            self.targetObject = targetObject
            self.onObjectFound = onObjectFound
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

            guard let image = info[.originalImage] as? UIImage else {
                picker.dismiss(animated: true)
                return
            }

            capturedImage = image

            picker.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }

                self.isImageCaptured = true
                self.visionClassifier.classifyImage(image, targetObject: self.targetObject) { found, confidence, topText in
                    DispatchQueue.main.async {
                        if found {
                            self.classificationResult = String(
                                format: NSLocalizedString("Found %@! ✅\n%@", comment: ""),
                                self.targetObject,
                                topText
                            )
                            self.onObjectFound(true, confidence, topText)
                        } else {
                            self.classificationResult = "❌ \(topText)"
                            self.onObjectFound(false, confidence, topText)
                        }
                    }
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            capturedImage: $capturedImage,
            classificationResult: $classificationResult,
            isImageCaptured: $isImageCaptured,
            visionClassifier: visionClassifier,
            targetObject: targetObject,
            onObjectFound: onObjectFound
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("❌ Camera not available")
            return imagePicker
        }

        imagePicker.sourceType = .camera
        imagePicker.delegate = context.coordinator
        imagePicker.allowsEditing = false
        imagePicker.cameraCaptureMode = .photo
        imagePicker.cameraDevice = .rear
        imagePicker.showsCameraControls = true
        imagePicker.modalPresentationStyle = .overFullScreen
        imagePicker.mediaTypes = ["public.image"]

        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// MARK: - Main Camera View (SwiftUI)
struct CameraView: View {
    @Binding var capturedImage: UIImage?
    @Binding var classificationResult: String?
    @Binding var isImageCaptured: Bool

    @ObservedObject var visionClassifier: VisionClassifier
    let targetObject: String
    let onObjectFound: (Bool, Double, String) -> Void

    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraViewControllerWrapper(
                capturedImage: $capturedImage,
                classificationResult: $classificationResult,
                isImageCaptured: $isImageCaptured,
                visionClassifier: visionClassifier,
                targetObject: targetObject,
                onObjectFound: onObjectFound
            )
            .ignoresSafeArea()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onChange(of: isImageCaptured) { captured in
            if captured {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        }
    }
}

