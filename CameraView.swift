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
    var isLiveDetectionEnabled: Bool = true

    @ObservedObject var visionClassifier: VisionClassifier
    let targetObject: String
    let onObjectFound: (Bool, Double, String) -> Void

    class CameraViewController: UIViewController {
        var captureSession: AVCaptureSession!
        var stillImageOutput: AVCapturePhotoOutput?
        var videoDataOutput: AVCaptureVideoDataOutput?
        var previewLayer: AVCaptureVideoPreviewLayer!
        let liveDetector = LiveCameraObjectDetector()
        let detectionOverlay = CameraDetectionOverlayView()

        var capturedImage: Binding<UIImage?>
        var classificationResult: Binding<String?>
        var isImageCaptured: Binding<Bool>

        var visionClassifier: VisionClassifier

        var targetObject: String
        var onObjectFound: (Bool, Double, String) -> Void
        /// يُقرأ على الـ main thread فقط؛ الكاشف عنده نسخته على طابوره.
        var isLiveDetectionEnabled = true
        private var isCapturingPhoto = false

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
            liveDetector.onDetections = { [weak self] detections, imageSize in
                guard let self else { return }
                guard self.isLiveDetectionEnabled else {
                    self.detectionOverlay.boxes = []
                    return
                }
                self.detectionOverlay.boxes = CameraBoundingBoxConverter.annotations(
                    from: detections,
                    imageSize: imageSize,
                    layerBounds: self.detectionOverlay.bounds,
                    targetObject: self.targetObject
                )
            }
            liveDetector.configure(enabled: isLiveDetectionEnabled, targetObject: targetObject)
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
                let photoOutput = AVCapturePhotoOutput()

                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(self, queue: liveDetector.queue)

                if captureSession.canAddInput(input),
                   captureSession.canAddOutput(photoOutput),
                   captureSession.canAddOutput(videoOutput) {
                    captureSession.addInput(input)
                    captureSession.addOutput(photoOutput)
                    captureSession.addOutput(videoOutput)
                    // الإطارات تطلع عمودية، فالكاشف يعاملها كـ .up
                    if let connection = videoOutput.connection(with: .video) {
                        connection.videoOrientation = .portrait
                    }
                    stillImageOutput = photoOutput
                    videoDataOutput = videoOutput
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
        }

        func setLiveDetectionEnabled(_ enabled: Bool) {
            isLiveDetectionEnabled = enabled
            if !enabled {
                detectionOverlay.boxes = []
            }
            liveDetector.configure(enabled: enabled, targetObject: targetObject)
        }

        @objc func capturePhoto() {
            // بدون كاميرا (المحاكي) ما فيه output، ونمنع الالتقاط المزدوج
            guard let stillImageOutput, !isCapturingPhoto, captureSession?.isRunning == true else { return }
            isCapturingPhoto = true
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            stillImageOutput.capturePhoto(with: settings, delegate: self)
        }

        fileprivate func handleCapturedPhoto(_ image: UIImage?) {
            isCapturingPhoto = false
            guard let image else { return }

            capturedImage.wrappedValue = image
            isImageCaptured.wrappedValue = true
            setLiveDetectionEnabled(false)

            // GameView يشيل الكاميرا بعد الالتقاط، فنمسك النتيجة بنسخ محلية بدل self
            let classificationResult = self.classificationResult
            let onObjectFound = self.onObjectFound
            visionClassifier.classifyImage(image, targetObject: targetObject) { found, confidence, detail in
                classificationResult.wrappedValue = found ? "✅ \(detail)" : "❌ \(detail)"
                onObjectFound(found, confidence, detail)
            }
        }
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(
            capturedImage: $capturedImage,
            classificationResult: $classificationResult,
            isImageCaptured: $isImageCaptured,
            visionClassifier: visionClassifier,
            targetObject: targetObject,
            onObjectFound: onObjectFound
        )
        controller.isLiveDetectionEnabled = isLiveDetectionEnabled && !isImageCaptured
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.targetObject = targetObject
        uiViewController.onObjectFound = onObjectFound
        uiViewController.setLiveDetectionEnabled(isLiveDetectionEnabled && !isImageCaptured)
        if captureTrigger {
            uiViewController.capturePhoto()
            DispatchQueue.main.async {
                self.captureTrigger = false
            }
        }
    }
}

// MARK: - Live video frames
extension CameraPreviewView.CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// يشتغل على `liveDetector.queue`، فما نلمس أي حالة SwiftUI هنا.
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        liveDetector.process(sampleBuffer: sampleBuffer)
    }
}

// MARK: - Capture Delegate
extension CameraPreviewView.CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        var image: UIImage?
        if let error = error {
            print("❌ Photo capture error: \(error.localizedDescription)")
        } else if let imageData = photo.fileDataRepresentation() {
            image = UIImage(data: imageData)
        }

        DispatchQueue.main.async {
            self.handleCapturedPhoto(image)
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


// MARK: - Live object detection (Apple Vision, on device)

struct LiveDetection: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var confidence: Float
    /// Vision normalized rect (origin bottom-left, 0…1)
    var visionBoundingBox: CGRect
}

/// يرسم مربع حول أبرز جسم في الكاميرا ويسمّيه من تصنيف Vision للصورة كاملة.
/// كل حالته تعيش على `queue` (نفس طابور إطارات الفيديو).
final class LiveCameraObjectDetector {
    let queue = DispatchQueue(label: "sbog.live.vision", qos: .userInitiated)

    private let sequenceHandler = VNSequenceRequestHandler()
    private var frameIndex = 0
    private var lastTopLabels: [(String, Float)] = []
    private var lastEmitTime: CFAbsoluteTime = 0
    private var isEnabled = true
    private var targetObject = ""

    /// يُستدعى على الـ main thread مع حجم الإطار (عمودي).
    var onDetections: (([LiveDetection], CGSize) -> Void)?

    func configure(enabled: Bool, targetObject: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let targetChanged = self.targetObject != targetObject
            let wasEnabled = self.isEnabled
            self.isEnabled = enabled
            self.targetObject = targetObject
            if (wasEnabled && !enabled) || targetChanged {
                self.frameIndex = 0
                self.lastTopLabels = []
                self.lastEmitTime = 0
                DispatchQueue.main.async { self.onDetections?([], .zero) }
            }
        }
    }

    /// يُستدعى على `queue`.
    func process(sampleBuffer: CMSampleBuffer) {
        guard isEnabled, !targetObject.isEmpty else { return }
        frameIndex += 1
        guard frameIndex % 5 == 0 else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let orientation = cgImageOrientation(from: sampleBuffer)
        let imageSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        if lastTopLabels.isEmpty || frameIndex % 20 == 0 {
            refreshLabels(pixelBuffer: pixelBuffer, orientation: orientation)
        }

        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        do {
            try sequenceHandler.perform([saliencyRequest], on: pixelBuffer, orientation: orientation)
        } catch {
            return
        }

        var detections: [LiveDetection] = []
        if let observation = saliencyRequest.results?.first,
           let region = observation.salientObjects?.max(by: { $0.confidence < $1.confidence }),
           let label = bestLabel() {
            detections.append(
                LiveDetection(label: label.0, confidence: label.1, visionBoundingBox: region.boundingBox)
            )
        }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastEmitTime >= 0.14 else { return }
        lastEmitTime = now
        DispatchQueue.main.async { [weak self] in
            self?.onDetections?(detections, imageSize)
        }
    }

    private func refreshLabels(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let request = VNClassifyImageRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch { return }

        lastTopLabels = (request.results ?? [])
            .prefix(8)
            .map { ($0.identifier, Float($0.confidence)) }
    }

    /// الغرض المطلوب إذا ظهر في أعلى التصنيفات، وإلا أعلى تصنيف نعرف له اسم عربي.
    private func bestLabel() -> (String, Float)? {
        if let match = lastTopLabels.first(where: { ObjectSynonyms.matches(label: $0.0, target: targetObject) }) {
            return match
        }
        return lastTopLabels.first(where: { $0.1 >= 0.12 && ObjectDisplayNames.arabic(fromVisionLabel: $0.0) != nil })
    }

    private func cgImageOrientation(from sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
        guard let attachment = CMGetAttachment(
            sampleBuffer,
            key: kCGImagePropertyOrientation,
            attachmentModeOut: nil
        ) as? UInt32 else {
            // الـ connection مضبوط على portrait، فالإطار أصلاً معدول
            return .up
        }
        return CGImagePropertyOrientation(rawValue: attachment) ?? .up
    }
}

enum CameraBoundingBoxConverter {
    static func annotations(
        from detections: [LiveDetection],
        imageSize: CGSize,
        layerBounds: CGRect,
        targetObject: String
    ) -> [CameraBoxAnnotation] {
        guard imageSize.width > 0, imageSize.height > 0 else { return [] }

        return detections.enumerated().compactMap { index, detection in
            guard let title = ObjectDisplayNames.arabic(fromVisionLabel: detection.label) else { return nil }

            let layerRect = layerRect(
                forVisionRect: detection.visionBoundingBox,
                imageSize: imageSize,
                layerBounds: layerBounds
            )
            return CameraBoxAnnotation(
                rect: shrinkTowardCenter(layerRect, fraction: 0.14),
                titleArabic: title,
                isPrimary: ObjectSynonyms.matches(label: detection.label, target: targetObject),
                labelOnTrailing: index % 2 == 0
            )
        }
    }

    /// يحوّل مستطيل Vision (0…1، الأصل تحت يسار) لإحداثيات الشاشة مع `resizeAspectFill`.
    private static func layerRect(forVisionRect box: CGRect, imageSize: CGSize, layerBounds: CGRect) -> CGRect {
        let scale = max(layerBounds.width / imageSize.width, layerBounds.height / imageSize.height)
        let displayed = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offsetX = (layerBounds.width - displayed.width) / 2
        let offsetY = (layerBounds.height - displayed.height) / 2

        return CGRect(
            x: offsetX + box.minX * displayed.width,
            y: offsetY + (1 - box.maxY) * displayed.height,
            width: box.width * displayed.width,
            height: box.height * displayed.height
        )
    }

    /// يصغّر المستطيل نحو المركز (الـ saliency غالباً أوسع من الجسم).
    private static func shrinkTowardCenter(_ rect: CGRect, fraction: CGFloat) -> CGRect {
        rect.insetBy(dx: rect.width * fraction / 2, dy: rect.height * fraction / 2)
    }
}

// MARK: - Detection overlay

struct CameraBoxAnnotation {
    let rect: CGRect
    let titleArabic: String
    let isPrimary: Bool
    let labelOnTrailing: Bool
}

final class CameraDetectionOverlayView: UIView {
    var boxes: [CameraBoxAnnotation] = [] {
        didSet { setNeedsDisplay() }
    }

    private let dashPattern: [CGFloat] = [7, 5]
    private let primaryColor = UIColor(red: 0.22, green: 0.78, blue: 0.42, alpha: 1)
    private let secondaryColor = UIColor(red: 0.98, green: 0.78, blue: 0.18, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        for box in boxes {
            let color = box.isPrimary ? primaryColor : secondaryColor
            drawDashedBox(box.rect, color: color)
            drawPillLabel(
                title: box.titleArabic,
                near: box.rect,
                color: color,
                showCheck: box.isPrimary,
                onTrailing: box.labelOnTrailing
            )
        }
    }

    private func drawDashedBox(_ box: CGRect, color: UIColor) {
        let path = UIBezierPath(roundedRect: box, cornerRadius: 10)
        path.lineWidth = 2.5
        path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        color.setStroke()
        path.stroke()
    }

    private func drawPillLabel(
        title: String,
        near box: CGRect,
        color: UIColor,
        showCheck: Bool,
        onTrailing: Bool
    ) {
        let display = showCheck ? "✓ \(title)" : title
        let font = UIFont.systemFont(ofSize: 13, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let textSize = (display as NSString).size(withAttributes: attributes)
        let hPad: CGFloat = 10
        let vPad: CGFloat = 5
        let pillW = textSize.width + hPad * 2
        let pillH = textSize.height + vPad * 2

        var pillX = onTrailing ? box.maxX - pillW : box.minX
        var pillY = box.minY - pillH - 4
        pillX = max(4, min(bounds.width - pillW - 4, pillX))
        if pillY < 4 {
            // ما فيه مكان فوق المربع، نحطه داخله
            pillY = box.minY + 6
        }

        let pillRect = CGRect(x: pillX, y: pillY, width: pillW, height: pillH)
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2)
        color.setFill()
        pillPath.fill()

        (display as NSString).draw(
            in: pillRect.insetBy(dx: hPad, dy: vPad),
            withAttributes: attributes
        )
    }
}
