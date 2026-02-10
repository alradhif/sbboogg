//
//  Untitled 3.swift
//  sbog
//
//  Created by roaa on 23/07/1447 AH.
//

import UIKit
import Vision

final class VisionClassifier: ObservableObject {

    // نفس شكل دالتك القديمة عشان ما نتعب في الدمج
    func classifyImage(_ image: UIImage, targetObject: String, completion: @escaping (Bool, Double, String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(false, 0.0, "No CGImage")
            return
        }

        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                completion(false, 0.0, "Vision error: \(error.localizedDescription)")
                return
            }

            let results = (request.results as? [VNClassificationObservation]) ?? []
            let top = Array(results.prefix(5))

            let target = targetObject.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let synonyms = self.synonyms(for: target)

            // طلع نص أفضل نتيجة للعرض
            let topText = top.first.map { "\($0.identifier) (\(String(format: "%.2f", $0.confidence)))" } ?? "No results"

            // قرار المطابقة
            for r in top {
                let label = r.identifier.lowercased()
                let conf = Double(r.confidence)

                // threshold بسيط
                if conf < 0.25 { continue }

                if synonyms.contains(where: { label.contains($0) }) {
                    completion(true, conf, topText)
                    return
                }
            }

            completion(false, Double(top.first?.confidence ?? 0.0), topText)
        }

        

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func synonyms(for target: String) -> [String] {
        switch target {
        case "book":
            return ["book", "notebook", "comic", "book jacket"]
        case "glasses":
            return ["glasses", "sunglasses", "eyewear", "goggles"]
        case "water bottle":
            return ["bottle", "water bottle"]
        case "shoes":
            return ["shoe", "sneaker", "running shoe", "boot"]
        case "bed":
            return ["bed", "bunk bed"]
        default:
            return [target]
        }
    }
}
