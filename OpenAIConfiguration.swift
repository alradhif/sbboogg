//
//  OpenAIConfiguration.swift
//  sbog
//

import Foundation

enum OpenAIConfiguration {
    /// Copy `Secrets.plist.example` to `Secrets.plist` and add your API key (file is gitignored).
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
