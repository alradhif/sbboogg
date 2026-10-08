//
//  UsernameEntryView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import MultipeerConnectivity
import SwiftData

struct UsernameEntryView: View {
    @Binding var username: String
    @Binding var showLobby: Bool
    @Binding var isHost: Bool
    @ObservedObject var multipeerService: MultipeerService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var profileManager = ProfileManager()
    @State private var availableHosts: [MCPeerID] = []
    @State private var isSearching: Bool = false
    @State private var showProfile: Bool = false
    @State private var showJoinHint: Bool = false
    @State private var showInviteHint: Bool = false
    @State private var usernameFromProfile: Bool = false
    
    private var profileAvatarName: String {
        PlayerAvatars.imageName(for: profileManager.currentProfile?.avatarImageName)
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            // Hidden navigation trigger to lobby when showLobby becomes true
            NavigationLink(
                destination: LobbyView(multipeerService: multipeerService, isHost: isHost),
                isActive: $showLobby
            ) {
                EmptyView()
            }
            .opacity(0)
            .accessibilityHidden(true)
            
            GeometryReader { geo in
                Image("stig")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 1.1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(x: -12, y: 230)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 24) {
                        HStack {
                            Spacer()
                            Button(action: {
                                showProfile = true
                            }) {
                                if usernameFromProfile {
                                    Image(profileAvatarName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(AppTheme.accent.opacity(0.3), lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().stroke(AppTheme.accent.opacity(0.3), lineWidth: 2))
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 10)
                        }

                        Image("camel")
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(geo.size.height * 0.25, 240))
                            .padding(.horizontal, usernameFromProfile ? 80 : 0)

                        VStack(spacing: 10) {
                            if usernameFromProfile {
                                Text(username)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 40)
                                    .background(AppTheme.surface)
                                    .cornerRadius(38)
                            } else {
                                TextField("أسم السبوق", text: $username)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .cornerRadius(38)
                                    .padding(.horizontal, 40)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)

                                if username.isEmpty {
                                    Text("الرجاء إدخال اسم المستخدم")
                                        .foregroundColor(AppTheme.error)
                                        .font(.appCaption)
                                }
                            }
                        }

                        VStack(spacing: 14) {
                            Button(action: {
                                showInviteHint = true
                            }) {
                                Text("اعزمهم على مجموعتك")
                                    .font(.appHeadline)
                                    .foregroundColor(AppTheme.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(username.isEmpty ? Color.gray : AppTheme.accentSoft)
                                    .cornerRadius(24)
                            }
                            .disabled(username.isEmpty)
                            .padding(.horizontal, 32)

                            Button(action: {
                                showJoinHint = true
                            }) {
                                Text("اقلط بمجموعه")
                                    .font(.appHeadline)
                                    .foregroundColor(AppTheme.textOnAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(username.isEmpty ? Color.gray : AppTheme.accent)
                                    .cornerRadius(24)
                            }
                            .disabled(username.isEmpty)
                            .padding(.horizontal, 32)
                        }
                        .padding(.top, 10)

                        if isSearching {
                            ProgressView("Searching for games...")
                                .padding(.top, 16)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: geo.size.height)
                }
            }
            
            if showJoinHint {
                JoinHintView(
                    onContinue: {
                        showJoinHint = false
                        startAsGuest()
                    },
                    onDismiss: {
                        showJoinHint = false
                    }
                )
                .zIndex(100)
                .transition(.opacity)
            }
            
            if showInviteHint {
                InviteHintView(
                    onContinue: {
                        showInviteHint = false
                        startAsHost()
                    },
                    onDismiss: {
                        showInviteHint = false
                    }
                )
                .zIndex(100)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(
                profileManager: profileManager,
                onLogout: {
                    profileManager.clearCurrentProfile()
                    username = ""
                    usernameFromProfile = false
                    showLobby = false
                    isHost = false
                    showProfile = false
                }
            )
            .environment(\.layoutDirection, .leftToRight)
        }
        .onAppear {
            profileManager.setModelContext(modelContext)
            if let profile = profileManager.currentProfile {
                username = profile.username
                usernameFromProfile = true
            }
        }
        .onChange(of: showProfile) { oldValue, newValue in
            if oldValue == true && newValue == false {
                if let profile = profileManager.currentProfile {
                    username = profile.username
                    usernameFromProfile = true
                } else {
                    username = ""
                    usernameFromProfile = false
                    showLobby = false
                    isHost = false
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    func startAsHost() {
        guard !username.isEmpty else { return }
        let profile = profileManager.getOrCreateLocalProfile(username: username.trimmingCharacters(in: .whitespaces))
        isHost = true
        multipeerService.startHosting(
            username: username.trimmingCharacters(in: .whitespaces),
            avatarImageName: profile.avatarImageName
        )
        showLobby = true
    }
    
    func startAsGuest() {
        guard !username.isEmpty else { return }
        let profile = profileManager.getOrCreateLocalProfile(username: username.trimmingCharacters(in: .whitespaces))
        isHost = false
        isSearching = true
        multipeerService.startBrowsing(
            username: username.trimmingCharacters(in: .whitespaces),
            avatarImageName: profile.avatarImageName
        )
        
        // Wait a bit for discovery, then show lobby
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            showLobby = true
        }
    }
}

// MARK: - Join Hint (التعليمات - الإجتماع)
struct JoinHintView: View {
    var onContinue: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 0) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .zIndex(1)
                    .offset(y: 8)
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("التعليمات")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text("1")
                        .font(.appTitle(28))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("الإجتماع")
                        .font(.appTitle(22))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Rectangle()
                        .fill(AppTheme.textSecondary.opacity(0.3))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                    
                    Text("حدد الميدان، خش مع مجموعة\nأو اعزم ربعك، وخلوكم جنب بعض\nعشان يتفعّل البلوتوث")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 12) {
                        Button(action: onDismiss) {
                            Text("إلغاء")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Button(action: onContinue) {
                            Text("استمر")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(24)
                .frame(maxWidth: 320)
                .background(AppTheme.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.textPrimary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .offset(y: -20)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Invite Hint (التعليمات - الدعوات)
struct InviteHintView: View {
    var onContinue: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 0) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .zIndex(1)
                    .offset(y: 8)
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("التعليمات")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text("الدعوات")
                        .font(.appTitle(22))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Rectangle()
                        .fill(AppTheme.textSecondary.opacity(0.3))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                    
                    Text("انتظر قبول الدعوات التي أرسلتها وبعدها ننطلق.")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 12) {
                        Button(action: onDismiss) {
                            Text("إلغاء")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Button(action: onContinue) {
                            Text("استمر")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(24)
                .frame(maxWidth: 320)
                .background(AppTheme.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.textPrimary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .offset(y: -20)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

#Preview {
    UsernameEntryView(
        username: .constant("Test"),
        showLobby: .constant(false),
        isHost: .constant(false),
        multipeerService: MultipeerService()
    )
}
