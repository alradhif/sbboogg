//
//  VisionClassifier.swift
//  sbog
//

import UIKit

final class VisionClassifier: ObservableObject {

    @Published var isClassifying = false

    private var classifyGeneration: UInt = 0
    private let prepQueue = DispatchQueue(label: "sbog.vision.prep", qos: .userInitiated)

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        return URLSession(configuration: config)
    }()

    /// يُلغي أي طلب تحليل قيد الانتظار (مثلاً عند بدء جولة جديدة).
    func cancelPending() {
        classifyGeneration += 1
        DispatchQueue.main.async { self.isClassifying = false }
    }

    func classifyImage(
        _ image: UIImage,
        targetObject: String,
        completion: @escaping (Bool, Double, String) -> Void
    ) {
        guard let apiKey = OpenAIConfiguration.apiKey else {
            print("⚠️ OpenAI: لا يوجد مفتاح — عدّل Secrets.plist ثم Build من Xcode")
            completion(false, 0.0, "خدمة التحقق غير متوفرة حالياً")
            return
        }

        classifyGeneration += 1
        let generation = classifyGeneration
        let target = targetObject.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async { self.isClassifying = true }

        prepQueue.async { [weak self] in
            guard let self else { return }
            guard generation == self.classifyGeneration else { return }

            guard let jpegData = self.resizedJPEGData(from: image.normalizedForVision()) else {
                DispatchQueue.main.async {
                    if generation == self.classifyGeneration { self.isClassifying = false }
                    completion(false, 0.0, "تعذّر تجهيز الصورة")
                }
                return
            }

            let prompt = self.visionPrompt(for: target)
            let base64 = jpegData.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64)"

            let body: [String: Any] = [
                "model": OpenAIConfiguration.visionModel,
                "response_format": ["type": "json_object"],
                "max_tokens": 80,
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            ["type": "text", "text": prompt],
                            ["type": "image_url", "image_url": ["url": dataURL, "detail": "low"]]
                        ]
                    ]
                ]
            ]

            var request = URLRequest(url: OpenAIConfiguration.chatCompletionsURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 25

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                DispatchQueue.main.async {
                    if generation == self.classifyGeneration { self.isClassifying = false }
                    completion(false, 0.0, "خطأ في الطلب")
                }
                return
            }

            self.session.dataTask(with: request) { [weak self] data, response, error in
                defer {
                    DispatchQueue.main.async {
                        guard let self, generation == self.classifyGeneration else { return }
                        self.isClassifying = false
                    }
                }

                guard generation == self?.classifyGeneration else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, 0.0, error.localizedDescription)
                    }
                    return
                }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(false, 0.0, "لا توجد استجابة من الخادم")
                }
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let message = Self.apiErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
                DispatchQueue.main.async {
                    completion(false, 0.0, message)
                }
                return
            }

            guard let parsed = Self.parseClassification(from: data) else {
                DispatchQueue.main.async {
                    completion(false, 0.0, "تعذّر قراءة نتيجة التحليل")
                }
                return
            }

            let display = parsed.reason?.isEmpty == false
                ? parsed.reason!
                : (parsed.found ? "تم التعرف على \(target)" : "لم يُعثر على \(target)")
            let confidence = min(max(parsed.confidence, 0), 1)
            let accepted = parsed.found && confidence >= 0.45
            print("🔍 OpenAI: target=\(target) found=\(parsed.found) conf=\(confidence) accepted=\(accepted)")
            DispatchQueue.main.async {
                completion(accepted, confidence, display)
            }
            }.resume()
        }
    }

    // MARK: - Helpers

    private func visionPrompt(for target: String) -> String {
        let hints = synonymHints(for: target.lowercased())
        let hintLine = hints.isEmpty ? "" : " Acceptable matches include: \(hints.joined(separator: ", "))."

        return """
        You are judging a scavenger-hunt photo. The player must find this object: "\(target)".\(hintLine)
        Look at the image. Is that object clearly visible (photo of a real object, not a screen or drawing)?
        Reply with JSON only, keys: found (boolean), confidence (number 0 to 1), reason (short phrase in Arabic).
        Be fair: partial visibility of the correct object can count if identifiable.
        """
    }

    private func synonymHints(for target: String) -> [String] {
        switch target {
        case "book": return ["book", "notebook", "textbook"]
        case "glasses": return ["glasses", "sunglasses", "eyewear"]
        case "water bottle": return ["water bottle", "bottle"]
        case "phone", "mobile", "smartphone": return ["phone", "smartphone", "mobile phone"]
        case "cup", "mug": return ["cup", "mug", "coffee cup"]
        case "bag", "backpack", "handbag": return ["bag", "backpack", "handbag", "purse"]
        case "shoes": return ["shoes", "sneakers", "footwear"]
        case "pen": return ["pen", "ballpoint pen", "pencil"]
        case "watch": return ["watch", "wristwatch"]
        case "keys": return ["keys", "keychain"]
        default: return [target]
        }
    }

    private func resizedJPEGData(from image: UIImage, maxDimension: CGFloat = 768, quality: CGFloat = 0.68) -> Data? {
        let size = image.size
        let maxSide = max(size.width, size.height)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    private struct ClassificationResult: Decodable {
        let found: Bool
        let confidence: Double
        let reason: String?
    }

    private static func parseClassification(from data: Data) -> ClassificationResult? {
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = chat.choices.first?.message.content.data(using: .utf8),
              let result = try? JSONDecoder().decode(ClassificationResult.self, from: content) else {
            return nil
        }
        return result
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        struct APIError: Decodable {
            struct Detail: Decodable {
                let message: String
            }
            let error: Detail
        }
        return (try? JSONDecoder().decode(APIError.self, from: data))?.error.message
    }
}

private extension UIImage {
    /// يصحّح اتجاه صورة الكاميرا قبل إرسالها لـ OpenAI.
    func normalizedForVision() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
