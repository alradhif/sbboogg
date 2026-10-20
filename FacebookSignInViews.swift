//
//  FacebookSignInViews.swift
//  sbog
//
//  Buttons for online sign-in. SignInOptionsView goes before online play;
//  LinkFacebookButton goes in ProfileView for players who are still guests.
//

import SwiftUI

private let facebookBlue = Color(hex: "1877F2")

struct SignInOptionsView: View {
    @ObservedObject var auth = AuthService.shared

    var body: some View {
        VStack(spacing: 14) {
            Text("العب أونلاين")
                .font(.appTitle(28))
                .foregroundColor(AppTheme.accent)

            Text("سجّل بفيسبوك عشان تحفظ نقاطك وجملك، أو ادخل كضيف وتقدر تربط فيسبوك بعدين.")
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            FacebookButton(title: "كمّل مع فيسبوك", isWorking: auth.isWorking) {
                Task { await auth.signInWithFacebook() }
            }

            Button {
                Task { await auth.signInAsGuest() }
            } label: {
                Text("العب كضيف")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.accent.opacity(0.3), lineWidth: 2))
            }
            .disabled(auth.isWorking)

            if let message = auth.errorMessage {
                Text(message)
                    .font(.appCaption)
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
    }
}

/// Shown only while the player is a guest. Linking keeps the same account,
/// so nothing is lost.
struct LinkFacebookButton: View {
    @ObservedObject var auth = AuthService.shared

    var body: some View {
        if auth.state == .guest {
            VStack(spacing: 8) {
                FacebookButton(title: "اربط حسابك بفيسبوك", isWorking: auth.isWorking) {
                    Task { await auth.linkFacebook() }
                }
                Text("نقاطك وعلفك وجملك تبقى مثل ما هي.")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)

                if let message = auth.errorMessage {
                    Text(message)
                        .font(.appCaption)
                        .foregroundColor(AppTheme.error)
                        .multilineTextAlignment(.center)
                }
            }
        } else if auth.state == .facebook {
            Label("مربوط بفيسبوك", systemImage: "checkmark.seal.fill")
                .font(.appCaption)
                .foregroundColor(AppTheme.success)
        }
    }
}

private struct FacebookButton: View {
    let title: String
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text("f")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(facebookBlue)
                        .frame(width: 28, height: 28)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(facebookBlue)
            .clipShape(Capsule())
        }
        .disabled(isWorking)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        SignInOptionsView()
    }
}
