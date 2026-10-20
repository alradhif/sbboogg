//
//  LiveCameraObjectDetector.swift
//  sbog
//

import AVFoundation
import Vision

struct LiveDetection: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var confidence: Float
    /// Vision normalized rect (origin bottom-left, 0…1)
    var visionBoundingBox: CGRect
}

final class LiveCameraObjectDetector {
    private let visionQueue = DispatchQueue(label: "sbog.live.vision", qos: .userInitiated)
    private let sequenceHandler = VNSequenceRequestHandler()
    private var frameIndex = 0
    private var lastTopLabels: [(String, Float)] = []

    var onDetections: (([LiveDetection]) -> Void)?

    func process(sampleBuffer: CMSampleBuffer, targetObject: String) {
        frameIndex += 1
        guard frameIndex % 2 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let orientation = cgImageOrientation(from: sampleBuffer)

        visionQueue.async { [weak self] in
            guard let self else { return }

            if self.frameIndex % 8 == 0 {
                self.refreshLabels(pixelBuffer: pixelBuffer, orientation: orientation)
            }

            let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
            do {
                try self.sequenceHandler.perform([saliencyRequest], on: pixelBuffer, orientation: orientation)
            } catch {
                return
            }

            guard let observation = saliencyRequest.results?.first as? VNSaliencyImageObservation else {
                DispatchQueue.main.async { self.onDetections?([]) }
                return
            }

            let salient = observation.salientObjects ?? []
            let synonyms = ObjectSynonyms.terms(for: targetObject)
            let labels = self.lastTopLabels

            var detections: [LiveDetection] = []
            for region in salient.prefix(3) {
                let (label, confidence) = self.bestLabel(for: region.boundingBox, labels: labels, synonyms: synonyms, fallbackTarget: targetObject)
                if confidence < 0.12 && detections.isEmpty == false { continue }
                detections.append(
                    LiveDetection(
                        label: label,
                        confidence: confidence,
                        visionBoundingBox: region.boundingBox
                    )
                )
            }

            if detections.isEmpty, let best = labels.first {
                if let region = salient.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                    detections.append(
                        LiveDetection(
                            label: best.0,
                            confidence: best.1,
                            visionBoundingBox: region.boundingBox
                        )
                    )
                }
            }

            let prioritized = self.prioritize(detections, synonyms: synonyms, targetObject: targetObject)
            DispatchQueue.main.async {
                self.onDetections?(prioritized)
            }
        }
    }

    func reset() {
        frameIndex = 0
        lastTopLabels = []
        DispatchQueue.main.async { self.onDetections?([]) }
    }

    private func refreshLabels(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let request = VNClassifyImageRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch { return }

        let top = (request.results as? [VNClassificationObservation])?
            .prefix(8)
            .map { ($0.identifier, Float($0.confidence)) } ?? []
        lastTopLabels = top
    }

    private func bestLabel(
        for box: CGRect,
        labels: [(String, Float)],
        synonyms: [String],
        fallbackTarget: String
    ) -> (String, Float) {
        for (name, conf) in labels {
            let lower = name.lowercased()
            if synonyms.contains(where: { lower.contains($0) }) {
                return (name, conf)
            }
        }
        if let first = labels.first {
            return first
        }
        return (fallbackTarget, 0)
    }

    private func prioritize(_ detections: [LiveDetection], synonyms: [String], targetObject: String) -> [LiveDetection] {
        guard !detections.isEmpty else { return [] }
        let sorted = detections.sorted { lhs, rhs in
            let lhsMatch = synonyms.contains(where: { lhs.label.lowercased().contains($0) })
            let rhsMatch = synonyms.contains(where: { rhs.label.lowercased().contains($0) })
            if lhsMatch != rhsMatch { return lhsMatch }
            return lhs.confidence > rhs.confidence
        }
        return Array(sorted.prefix(2))
    }

    private func cgImageOrientation(from sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
        guard let attachment = CMGetAttachment(
            sampleBuffer,
            key: kCGImagePropertyOrientation,
            attachmentModeOut: nil
        ) as? UInt32 else {
            return .right
        }
        return CGImagePropertyOrientation(rawValue: attachment) ?? .right
    }
}

enum ObjectSynonyms {
    static func terms(for target: String) -> [String] {
        switch target.lowercased() {
        case "book": return ["book", "notebook", "textbook", "comic"]
        case "glasses": return ["glasses", "sunglasses", "eyewear"]
        case "water bottle": return ["bottle", "water bottle"]
        case "phone", "mobile", "smartphone": return ["phone", "smartphone", "mobile"]
        case "cup", "mug": return ["cup", "mug"]
        case "bag", "backpack", "handbag": return ["bag", "backpack", "handbag", "purse"]
        case "shoes": return ["shoe", "sneaker", "footwear"]
        case "pen": return ["pen", "pencil"]
        case "watch": return ["watch", "wristwatch"]
        case "keys": return ["keys", "keychain"]
        default: return [target.lowercased()]
        }
    }
}

enum CameraBoundingBoxConverter {
    static func annotations(
        from detections: [LiveDetection],
        previewLayer: AVCaptureVideoPreviewLayer,
        targetObject: String
    ) -> [CameraBoxAnnotation] {
        let synonyms = ObjectSynonyms.terms(for: targetObject)
        let fallbackArabic = ObjectDisplayNames.arabicShort(forGameObject: targetObject)

        return detections.enumerated().compactMap { index, detection in
            let box = detection.visionBoundingBox
            let metadataRect = CGRect(
                x: box.minX,
                y: 1 - box.maxY,
                width: box.width,
                height: box.height
            )
            let layerRect = previewLayer.layerRectConverted(fromMetadataOutputRect: metadataRect)
            let tightened = shrinkTowardCenter(layerRect, fraction: 0.14)

            let mapped =
                ObjectDisplayNames.arabic(fromVisionLabel: detection.label)
                ?? ObjectDisplayNames.arabicShort(forGameObject: detection.label)
            let title = mapped.isEmpty ? fallbackArabic : mapped
            guard !title.isEmpty else { return nil }

            let labelLower = detection.label.lowercased()
            let matchesTarget = synonyms.contains { labelLower.contains($0) }
            let isPrimary = matchesTarget || index == 0

            return CameraBoxAnnotation(
                rect: tightened,
                titleArabic: title,
                isPrimary: isPrimary,
                labelOnTrailing: index % 2 == 0
            )
        }
    }

    /// يصغّر المستطيل نحو المركز (ساليency غالباً أوسع من الجسم).
    private static func shrinkTowardCenter(_ rect: CGRect, fraction: CGFloat) -> CGRect {
        let insetX = rect.width * fraction / 2
        let insetY = rect.height * fraction / 2
        return rect.insetBy(dx: insetX, dy: insetY)
    }
}
