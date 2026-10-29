//
//  RoomCodeField.swift
//  sbog
//
//  Five-character room code entry (LTR). Avoids RTL / SwiftUI TextField quirks in fullScreenCover.
//

import SwiftUI

enum RoomCodeFormatter {
    static func normalize(_ raw: String) -> String {
        let mapped = raw.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0x0660 ... 0x0669:
                return Character(Unicode.Scalar(0x30 + scalar.value - 0x0660)!)
            case 0x06F0 ... 0x06F9:
                return Character(Unicode.Scalar(0x30 + scalar.value - 0x06F0)!)
            default:
                return Character(scalar)
            }
        }
        let latin = String(mapped).uppercased()
        return String(latin.filter { $0.isLetter || $0.isNumber }.prefix(5))
    }
}

struct RoomCodeField: View {
    @Binding var code: String
    var prompt: String = "XXXXX"

    var body: some View {
        TextField("", text: $code, prompt: Text(prompt).foregroundStyle(AppTheme.textSecondary))
            .font(.system(size: 26, weight: .heavy, design: .monospaced))
            .foregroundStyle(AppTheme.textPrimary)
            .tint(AppTheme.accent)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .keyboardType(.asciiCapable)
            .textFieldStyle(.plain)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onChange(of: code) { _, newValue in
                let cleaned = RoomCodeFormatter.normalize(newValue)
                if cleaned != newValue {
                    code = cleaned
                }
            }
    }
}
