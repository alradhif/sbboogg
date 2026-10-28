//
//  InvitationsView.swift
//  sbog
//

import SwiftUI

struct InvitationsView: View {
    @ObservedObject var multipeerService: MultipeerService
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            GeometryReader { geo in
                Image("stig")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.77)
                    .offset(x: -12, y: geo.size.height * 0.60)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                if multipeerService.pendingInvitations.isEmpty {
                    Spacer()
                    Text("ما فيه دعوات حالياً")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(multipeerService.pendingInvitations) { invitation in
                                InvitationCard(
                                    username: invitation.username,
                                    onAccept: {
                                        multipeerService.acceptInvitation(from: invitation.peerID)
                                        if multipeerService.pendingInvitations.isEmpty {
                                            onDismiss()
                                        }
                                    },
                                    onReject: {
                                        multipeerService.rejectInvitation(from: invitation.peerID)
                                        if multipeerService.pendingInvitations.isEmpty {
                                            onDismiss()
                                        }
                                    }
                                )
                            }
                            
                            if multipeerService.pendingInvitations.count > 2 {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Text("الدعوات")
                .font(.appTitle(24))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Image(multipeerService.avatarImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        }
        .padding(.horizontal, 20)
        .environment(\.layoutDirection, .leftToRight)
    }
}

private struct InvitationCard: View {
    let username: String
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("عندك دعوة من :")
                .font(.appCaption)
                .foregroundColor(AppTheme.textSecondary)
            
            Text(username)
                .font(.appTitle(28))
                .foregroundColor(AppTheme.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            HStack(spacing: 12) {
                Button(action: onReject) {
                    Text("رفض")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "4A4A4A"))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                Button(action: onAccept) {
                    Text("قبول")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.accentSoft, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    InvitationsView(
        multipeerService: MultipeerService(),
        onDismiss: {}
    )
}
