//
//  VisionClassifier.swift
//  sbog
//
//  التحقق من الصورة بعد الالتقاط: OpenAI Vision أولاً، وإذا ما فيه مفتاح
//  أو فشل الاتصال نرجع لـ Apple Vision على الجوال.
//

import UIKit
import Vision

final class VisionClassifier: ObservableObject {

    @Published var isClassifying = false

    /// يُقرأ ويُكتب على الـ main thread فقط.
    private var classifyGeneration: UInt = 0
    private let prepQueue = DispatchQueue(label: "sbog.vision.prep", qos: .userInitiated)

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        return URLSession(configuration: config)
    }()

    /// يُلغي أي طلب تحليل قيد الانتظار (مثلاً عند بدء جولة جديدة).
    func cancelPending() {
        runOnMain {
            self.classifyGeneration += 1
            self.isClassifying = false
        }
    }

    /// `completion` يُستدعى دائماً على الـ main thread، ولا يُستدعى إذا انلغى الطلب.
    func classifyImage(
        _ image: UIImage,
        targetObject: String,
        completion: @escaping (Bool, Double, String) -> Void
    ) {
        runOnMain {
            self.classifyGeneration += 1
            let generation = self.classifyGeneration
            self.isClassifying = true

            let target = targetObject.trimmingCharacters(in: .whitespacesAndNewlines)
            let finish: (Bool, Double, String) -> Void = { [weak self] found, confidence, detail in
                DispatchQueue.main.async {
                    guard let self, generation == self.classifyGeneration else { return }
                    self.isClassifying = false
                    completion(found, confidence, detail)
                }
            }

            self.prepQueue.async { [weak self] in
                guard let self else { return }
                let normalized = image.normalizedForVision()

                guard let apiKey = OpenAIConfiguration.apiKey else {
                    print("⚠️ OpenAI: لا يوجد مفتاح — نستخدم Vision على الجوال")
                    self.classifyOnDevice(normalized, target: target, completion: finish)
                    return
                }

                self.classifyWithOpenAI(normalized, target: target, apiKey: apiKey) { result in
                    switch result {
                    case .success(let verdict):
                        finish(verdict.found, verdict.confidence, verdict.detail)
                    case .failure(let error):
                        print("⚠️ OpenAI فشل (\(error.message)) — نستخدم Vision على الجوال")
                        self.classifyOnDevice(normalized, target: target, completion: finish)
                    }
                }
            }
        }
    }

    // MARK: - OpenAI

    private struct Verdict {
        let found: Bool
        let confidence: Double
        let detail: String
    }

    private struct ClassifierError: Error {
        let message: String
    }

    private func classifyWithOpenAI(
        _ image: UIImage,
        target: String,
        apiKey: String,
        completion: @escaping (Result<Verdict, ClassifierError>) -> Void
    ) {
        guard let jpegData = resizedJPEGData(from: image) else {
            completion(.failure(ClassifierError(message: "تعذّر تجهيز الصورة")))
            return
        }

        let dataURL = "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
        let body: [String: Any] = [
            "model": OpenAIConfiguration.visionModel,
            "response_format": ["type": "json_object"],
            "max_tokens": 150,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": visionPrompt(for: target)],
                        ["type": "image_url", "image_url": ["url": dataURL, "detail": "low"]]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: OpenAIConfiguration.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(ClassifierError(message: "خطأ في الطلب")))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(ClassifierError(message: error.localizedDescription)))
                return
            }
            guard let data = data else {
                completion(.failure(ClassifierError(message: "لا توجد استجابة من الخادم")))
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let message = Self.apiErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
                completion(.failure(ClassifierError(message: message)))
                return
            }
            guard let parsed = Self.parseClassification(from: data) else {
                completion(.failure(ClassifierError(message: "تعذّر قراءة نتيجة التحليل")))
                return
            }

            let confidence = min(max(parsed.confidence, 0), 1)
            let accepted = parsed.found && confidence >= 0.45
            let arabicTarget = ObjectDisplayNames.arabicShort(forGameObject: target)
            let targetLabel = arabicTarget.isEmpty ? target : arabicTarget
            let reason = parsed.reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = reason.isEmpty
                ? (accepted ? "لقينا \(targetLabel)" : "ما لقينا \(targetLabel)")
                : reason
            print("🔍 OpenAI: target=\(target) found=\(parsed.found) conf=\(confidence) accepted=\(accepted)")
            completion(.success(Verdict(found: accepted, confidence: confidence, detail: detail)))
        }.resume()
    }

    private func visionPrompt(for target: String) -> String {
        let hints = ObjectSynonyms.terms(for: target)
        let hintLine = hints.isEmpty ? "" : " Acceptable matches include: \(hints.joined(separator: ", "))."

        return """
        You are judging a scavenger-hunt photo. The player must find this object: "\(target)".\(hintLine)
        Look at the image. Is that object clearly visible (photo of a real object, not a screen or drawing)?
        Reply with JSON only, keys: found (boolean), confidence (number 0 to 1), reason (short phrase in Saudi Arabic, max 6 words).
        Be fair: partial visibility of the correct object can count if identifiable.
        """
    }

    private func resizedJPEGData(from image: UIImage, maxDimension: CGFloat = 768, quality: CGFloat = 0.68) -> Data? {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > 0 else { return nil }
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
                    let content: String?
                }
                let message: Message
            }
            let choices: [Choice]
        }

        guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = chat.choices.first?.message.content?.data(using: .utf8),
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

    // MARK: - On-device fallback (Apple Vision)

    private func classifyOnDevice(
        _ image: UIImage,
        target: String,
        completion: @escaping (Bool, Double, String) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(false, 0.0, "تعذّر تجهيز الصورة")
            return
        }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            completion(false, 0.0, "تعذّر تحليل الصورة")
            return
        }

        let top = ((request.results as? [VNClassificationObservation]) ?? []).prefix(5)
        let arabicTarget = ObjectDisplayNames.arabicShort(forGameObject: target)
        let targetLabel = arabicTarget.isEmpty ? target : arabicTarget

        for observation in top where observation.confidence >= 0.25 {
            if ObjectSynonyms.matches(label: observation.identifier, target: target) {
                completion(true, Double(observation.confidence), "لقينا \(targetLabel)")
                return
            }
        }

        let seen = top.first.flatMap { ObjectDisplayNames.arabic(fromVisionLabel: $0.identifier) }
        let detail = seen.map { "هذا شكله \($0)، مو \(targetLabel)" } ?? "ما لقينا \(targetLabel)"
        completion(false, Double(top.first?.confidence ?? 0), detail)
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

private extension UIImage {
    /// يصحّح اتجاه صورة الكاميرا قبل التحليل.
    func normalizedForVision() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - OpenAI configuration

enum OpenAIConfiguration {
    /// انسخ `Secrets.plist.example` إلى `Secrets.plist` وحط المفتاح (الملف في .gitignore)،
    /// وتأكد إن `Secrets.plist` مضاف للـ target في Xcode.
    static var apiKey: String? {
        if let stored = OpenAIKeyStore.savedKey() {
            return stored
        }
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["OPENAI_API_KEY"] as? String {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != "YOUR_OPENAI_API_KEY" {
                return trimmed
            }
        }
        return nil
    }

    static let visionModel = "gpt-4o-mini"
    static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    static var hasConfiguredKey: Bool { apiKey != nil }
}

/// للمطوّر فقط — مفتاح محفوظ في UserDefaults يتقدّم على Secrets.plist.
enum OpenAIKeyStore {
    private static let defaultsKey = "sbog.openai.api_key"

    static func savedKey() -> String? {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "YOUR_OPENAI_API_KEY" { return nil }
        return trimmed
    }
}

// MARK: - Object names

enum ObjectSynonyms {
    /// الكلمات الإنجليزية اللي نقبلها لكل غرض (لتصنيفات Vision وتلميحات OpenAI).
    static func terms(for target: String) -> [String] {
        switch target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "book": return ["book", "notebook", "textbook", "comic"]
        case "glasses": return ["glasses", "sunglasses", "eyewear", "goggles"]
        case "water bottle": return ["bottle", "water bottle"]
        case "phone", "mobile", "smartphone": return ["phone", "smartphone", "mobile"]
        case "cup", "mug": return ["cup", "mug"]
        case "bag", "backpack", "handbag": return ["bag", "backpack", "handbag", "purse"]
        case "shoes": return ["shoe", "sneaker", "footwear", "boot"]
        case "pen": return ["pen", "pencil"]
        case "watch": return ["watch", "wristwatch"]
        case "keys": return ["key", "keychain"]
        default: return [target.lowercased()]
        }
    }

    /// هل تصنيف Vision (مثل "water_bottle") يطابق أحد الكلمات؟ نطابق كلمات كاملة
    /// (مع جمع s/es) عشان "pen" ما تطابق "penguin".
    static func label(_ identifier: String, matchesAnyOf terms: [String]) -> Bool {
        let words = identifier.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        let joined = words.joined(separator: " ")
        return terms.contains { term in
            let term = term.lowercased()
            if term.contains(" ") { return joined.contains(term) }
            return words.contains { $0 == term || $0 == term + "s" || $0 == term + "es" }
        }
    }

    static func matches(label identifier: String, target: String) -> Bool {
        label(identifier, matchesAnyOf: terms(for: target))
    }
}

enum ObjectDisplayNames {
    /// اسم عربي قصير لعرضه على الكاميرا (بدون إنجليزي).
    static func arabicShort(forGameObject objectName: String) -> String {
        let key = objectName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch key {
        case "book": return "كتاب"
        case "water bottle": return "موية"
        case "phone", "mobile", "smartphone": return "جوال"
        case "cup", "mug": return "كوب"
        case "bag", "backpack", "handbag": return "شنطة"
        case "shoes", "sneakers", "sports shoes": return "جزمة"
        case "pen", "pencil": return "قلم"
        case "watch": return "ساعة"
        case "keys": return "مفاتيح"
        case "glasses": return "نظارة"
        default:
            return arabic(fromVisionLabel: key) ?? ""
        }
    }

    /// يحوّل تصنيف Vision الإنجليزي لاسم عربي إذا كان من أغراض اللعبة، وإلا `nil`.
    static func arabic(fromVisionLabel identifier: String) -> String? {
        let rules: [(String, String)] = [
            ("book", "كتاب"), ("notebook", "كتاب"), ("comic", "كتاب"),
            ("cup", "كوب"), ("mug", "كوب"),
            ("pen", "قلم"), ("pencil", "قلم"), ("ballpoint", "قلم"),
            ("phone", "جوال"), ("smartphone", "جوال"), ("mobile", "جوال"),
            ("bottle", "موية"),
            ("shoe", "جزمة"), ("sneaker", "جزمة"), ("boot", "جزمة"),
            ("bag", "شنطة"), ("backpack", "شنطة"), ("handbag", "شنطة"), ("purse", "شنطة"),
            ("watch", "ساعة"), ("wristwatch", "ساعة"),
            ("key", "مفاتيح"), ("keychain", "مفاتيح"),
            ("glasses", "نظارة"), ("sunglasses", "نظارة"), ("eyeglasses", "نظارة"), ("eyewear", "نظارة"),
        ]
        for (token, arabic) in rules where ObjectSynonyms.label(identifier, matchesAnyOf: [token]) {
            return arabic
        }
        return nil
    }
}
