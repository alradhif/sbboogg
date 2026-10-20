//
//  OpenAIKeyStorage.swift
//  sbog
//
//  للمطوّر فقط — المفتاح من Secrets.plist على الماك عند البناء.
//

import Foundation

enum OpenAIKeyStore {
    private static let defaultsKey = "sbog.openai.api_key"

    static func savedKey() -> String? {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "YOUR_OPENAI_API_KEY" { return nil }
        return trimmed
    }
}
