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
                ScrollView {
                    VStack(spacing: 24) {
                        HStack {
                            Spacer()
                            Button(action: {
                                showProfile = true
                            }) {
                                Image("Ellipse 12")
                                    .font(.title2)
                                    .foregroundColor(AppTheme.accent)
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 10)
                        }

                        Image("camel")
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(geo.size.height * 0.25, 240))

                        VStack(spacing: 10) {
                            TextField("أسم السبوق", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .cornerRadius(38)
                                .padding(.horizontal, 40)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)

                            if username.isEmpty {
                                Text("Please enter a username")
                                    .foregroundColor(AppTheme.error)
                                    .font(.appCaption)
                            }
                        }

                        VStack(spacing: 14) {
                            Button(action: {
                                startAsHost()
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
                                startAsGuest()
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
            
            // هنا
        }
        .sheet(isPresented: $showProfile) {
                    ProfileView(
                        profileManager: profileManager,
                        onLogout: {
                            profileManager.clearCurrentProfile()
                            username = ""
                            showLobby = false
                            isHost = false
                            showProfile = false
                        }
                    )
                }
        .onChange(of: showProfile) { oldValue, newValue in
            // When sheet is dismissed, check if profile was cleared
            if oldValue == true && newValue == false {
                if profileManager.currentProfile == nil {
                    username = ""
                    // Ensure we're on UsernameEntryView
                    showLobby = false
                    isHost = false
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            profileManager.setModelContext(modelContext)
            // Load existing profile if available
            if let profile = profileManager.currentProfile {
                username = profile.username
            }
        }
    }
    
    func startAsHost() {
        guard !username.isEmpty else { return }
        // Create or get profile for this username
        _ = profileManager.getOrCreateProfile(username: username.trimmingCharacters(in: .whitespaces))
        isHost = true
        multipeerService.startHosting(username: username.trimmingCharacters(in: .whitespaces))
        showLobby = true
    }
    
    func startAsGuest() {
        guard !username.isEmpty else { return }
        // Create or get profile for this username
        _ = profileManager.getOrCreateProfile(username: username.trimmingCharacters(in: .whitespaces))
        isHost = false
        isSearching = true
        multipeerService.startBrowsing(username: username.trimmingCharacters(in: .whitespaces))
        
        // Wait a bit for discovery, then show lobby
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            showLobby = true
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
