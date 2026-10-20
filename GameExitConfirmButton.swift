//
//  GameExitConfirmButton.swift
//  sbog
//

import SwiftUI

/// زر خروج من القيم مع تأكيد — يرجع لشاشة اسم المستخدم عبر `onConfirm`.
struct GameExitConfirmButton: View {
    let onConfirm: () -> Void

    @State private var showAlert = false

    var body: some View {
        Button {
            showAlert = true
        } label: {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.accent)
                .frame(width: 44, height: 44)
                .background(AppTheme.surface)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel("خروج من القيم")
        .alert("تنبيه", isPresented: $showAlert) {
            Button("لا، أبقى", role: .cancel) {}
            Button("أطلع من القيم", role: .destructive) {
                onConfirm()
            }
        } message: {
            Text("ترى بتطلع من القيم")
        }
    }
}
