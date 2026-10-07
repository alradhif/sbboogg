//
//  CameraView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import AVFoundation
import UIKit
import Vision

// MARK: - Camera Preview using AVCaptureSession
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var classificationResult: String?
    @Binding var isImageCaptured: Bool
    @Binding var captureTrigger: Bool

    @ObservedObject var visionClassifier: VisionClassifier
    let targetObject: String
    let onObjectFound: (Bool, Double) -> Void

    class CameraViewController: UIViewController {
        var captureSession: AVCaptureSession!
        var stillImageOutput: AVCapturePhotoOutput!
        var previewLayer: AVCaptureVideoPreviewLayer!

        var capturedImage: Binding<UIImage?>
        var classificationResult: Binding<String?>
        var isImageCaptured: Binding<Bool>

        // ✅ Vision classifier
        var visionClassifier: VisionClassifier

        var targetObject: String
        var onObjectFound: (Bool, Double) -> Void

        init(
            capturedImage: Binding<UIImage?>,
            classificationResult: Binding<String?>,
            isImageCaptured: Binding<Bool>,
            visionClassifier: VisionClassifier,
            targetObject: String,
            onObjectFound: @escaping (Bool, Double) -> Void
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
            captureSession.sessionPreset = .photo

            guard let backCamera = AVCaptureDevice.default(for: .video) else {
                print("❌ Unable to access back camera!")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: backCamera)
                stillImageOutput = AVCapturePhotoOutput()

                if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                    captureSession.addInput(input)
                    captureSession.addOutput(stillImageOutput)
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
        // keep target updated لو تغيرت الجولة
        uiViewController.targetObject = targetObject
        if captureTrigger {
            uiViewController.capturePhoto()
            DispatchQueue.main.async {
                self.captureTrigger = false
            }
        }
    }
}

// MARK: - Capture Delegate (Vision)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.visionClassifier.classifyImage(image, targetObject: self.targetObject) { found, confidence, topText in
                DispatchQueue.main.async {
                    if found {
                        self.classificationResult.wrappedValue = String(
                            format: NSLocalizedString("Found %@! ✅\n%@", comment: ""),
                            self.targetObject,
                            topText
                        )
                        self.onObjectFound(true, confidence)
                    } else {
                        self.classificationResult.wrappedValue = String(
                            format: NSLocalizedString("Not sure ❌\n%@", comment: ""),
                            topText
                        )
                        self.onObjectFound(false, confidence)
                    }
                }
            }
        }
    }
}

// MARK: - UIImagePickerController Wrapper (Vision)
struct CameraViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var classificationResult: String?
    @Binding var isImageCaptured: Bool

    @ObservedObject var visionClassifier: VisionClassifier
    let targetObject: String
    let onObjectFound: (Bool, Double) -> Void

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding var capturedImage: UIImage?
        @Binding var classificationResult: String?
        @Binding var isImageCaptured: Bool

        let visionClassifier: VisionClassifier
        let targetObject: String
        let onObjectFound: (Bool, Double) -> Void

        init(
            capturedImage: Binding<UIImage?>,
            classificationResult: Binding<String?>,
            isImageCaptured: Binding<Bool>,
            visionClassifier: VisionClassifier,
            targetObject: String,
            onObjectFound: @escaping (Bool, Double) -> Void
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

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isImageCaptured = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.visionClassifier.classifyImage(image, targetObject: self.targetObject) { found, confidence, topText in
                            DispatchQueue.main.async {
                                if found {
                                self.classificationResult = String(
                                    format: NSLocalizedString("Found %@! ✅\n%@", comment: ""),
                                    self.targetObject,
                                    topText
                                )
                                    self.onObjectFound(true, confidence)
                                } else {
                                self.classificationResult = String(
                                    format: NSLocalizedString("Not sure ❌\n%@", comment: ""),
                                    topText
                                )
                                    self.onObjectFound(false, confidence)
                                }
                            }
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
    let onObjectFound: (Bool, Double) -> Void

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

