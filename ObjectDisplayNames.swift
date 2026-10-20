//
//  ObjectDisplayNames.swift
//  sbog
//

import Foundation

enum ObjectDisplayNames {
    /// اسم عربي قصير لعرضه على الباوندينق (بدون إنجليزي).
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

    static func arabic(fromVisionLabel identifier: String) -> String? {
        let id = identifier.lowercased()
        let rules: [(String, String)] = [
            ("book", "كتاب"), ("notebook", "كتاب"), ("comic", "كتاب"),
            ("cup", "كوب"), ("mug", "كوب"), ("coffee", "كوب"),
            ("pen", "قلم"), ("pencil", "قلم"), ("ballpoint", "قلم"),
            ("phone", "جوال"), ("smartphone", "جوال"), ("mobile", "جوال"),
            ("bottle", "موية"), ("water", "موية"),
            ("shoe", "جزمة"), ("sneaker", "جزمة"), ("boot", "جزمة"),
            ("bag", "شنطة"), ("backpack", "شنطة"), ("handbag", "شنطة"),
            ("watch", "ساعة"), ("wristwatch", "ساعة"),
            ("key", "مفاتيح"),
            ("glass", "نظارة"), ("sunglass", "نظارة"),
        ]
        for (token, arabic) in rules where id.contains(token) {
            return arabic
        }
        if containsOnlyLatin(id) { return nil }
        return nil
    }

    private static func containsOnlyLatin(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        return text.range(of: #"^[a-z0-9_\s\-\.]+$"#, options: .regularExpression) != nil
    }
}
