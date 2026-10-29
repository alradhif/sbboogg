//
//  ProfileView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

//
//  ProfileView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject private var audioManager = BackgroundMusicManager.shared
    @Environment(\.dismiss) private var dismiss

    var isInitialSetup: Bool = false
    var multipeerService: MultipeerService?
    var onLogout: (() -> Void)?

    @State private var isEditing: Bool = false
    @State private var editedUsername: String = ""
    @State private var setupName: String = ""
    @State private var selectedAvatar: String = PlayerAvatars.defaultName
    @State private var showSettings: Bool = false
    @State private var navigateToUsernameEntry: Bool = false
    @State private var setupUsername: String = ""
    @State private var showLobby: Bool = false
    @State private var isHost: Bool = false

    init(
        profileManager: ProfileManager,
        isInitialSetup: Bool = false,
        multipeerService: MultipeerService? = nil,
        onLogout: (() -> Void)? = nil
    ) {
        self.profileManager = profileManager
        self.isInitialSetup = isInitialSetup
        self.multipeerService = multipeerService
        self.onLogout = onLogout
    }

    var body: some View {
        Group {
            if isInitialSetup {
                profileScreen
            } else {
                NavigationView {
                    profileScreen
                }
                .navigationViewStyle(.stack)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .fullScreenCover(isPresented: Binding(
            get: { !isInitialSetup && navigateToUsernameEntry },
            set: { navigateToUsernameEntry = $0 }
        )) {
            NavigationView {
                UsernameEntryView(
                    username: .constant(""),
                    showLobby: .constant(false),
                    isHost: .constant(false),
                    multipeerService: MultipeerService()
                )
            }
        }
    }

    private var profileScreen: some View {
        ZStack {
            Color(hex: "FFCB45")
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack(alignment: .center) {
                    Image("stig")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 1.1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .offset(y: 300)
                        .allowsHitTesting(false)

                    Image("logo1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .offset(y: geo.size.height * -0.10)
                        .opacity(0.88)
                        .blendMode(.screen)
                        .allowsHitTesting(false)

                    ScrollView {
                        VStack(spacing: 22) {
                            if isInitialSetup && profileManager.currentProfile == nil {
                                profileSetupContent
                            } else if let profile = profileManager.currentProfile {
                                profileMainContent(profile: profile)
                            } else {
                                Text("ما فيه ملف شخصي")
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .frame(maxWidth: min(geo.size.width - 48, 360))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .frame(minHeight: geo.size.height, alignment: .top)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .navigationBarHidden(isInitialSetup)
        .toolbarBackground(Color(hex: "FFCB45"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !isInitialSetup {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
        .background {
            if isInitialSetup, let service = multipeerService {
                NavigationLink(
                    "",
                    destination: UsernameEntryView(
                        username: $setupUsername,
                        showLobby: $showLobby,
                        isHost: $isHost,
                        multipeerService: service
                    ),
                    isActive: $navigateToUsernameEntry
                )
                .hidden()
            }
        }
        .onAppear {
            profileManager.setModelContext(modelContext)
            if let profile = profileManager.currentProfile {
                selectedAvatar = PlayerAvatars.imageName(for: profile.avatarImageName)
            }
        }
        .sheet(isPresented: $showSettings) {
            profileSettingsSheet
        }
    }

    private var profileSettingsSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: "FFCB45")
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    NavigationLink(destination: AllPlayersLeaderboardView(profileManager: profileManager)) {
                        Text("التصنيف")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                    }

                    musicSection

                    OnlineAccountSection()

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "FFCB45"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("تم") {
                        showSettings = false
                    }
                    .foregroundColor(AppTheme.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .navigationViewStyle(.stack)
        .environment(\.layoutDirection, .leftToRight)
    }

    func completeSetup() {
        let trimmed = setupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, multipeerService != nil else { return }

        _ = profileManager.getOrCreateLocalProfile(username: trimmed)
        profileManager.updateAvatar(selectedAvatar)
        setupUsername = trimmed
        navigateToUsernameEntry = true
    }

    // MARK: - Functions
    func startEditing() {
        if let profile = profileManager.currentProfile {
            editedUsername = profile.username
            isEditing = true
        }
    }

    func cancelEdit() {
        isEditing = false
        editedUsername = ""
    }

    func saveUsername() {
        guard let profile = profileManager.currentProfile else { return }
        guard !editedUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        profileManager.updateUsername(
            oldUsername: profile.username,
            newUsername: editedUsername.trimmingCharacters(in: .whitespaces)
        )
        isEditing = false
    }

    // MARK: - Profile Content

    private var profileSetupContent: some View {
        VStack(spacing: 22) {
            profileHeroImage(size: 130)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("أنشئ ملفك")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            setupNameCapsule

            avatarPickerSection(score: 999, allowAll: true)

            Button {
                completeSetup()
            } label: {
                Text("متابعة")
                    .font(.headline)
                    .foregroundColor(AppTheme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        setupName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gray
                            : AppTheme.accent
                    )
                    .clipShape(Capsule())
            }
            .disabled(setupName.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
    }

    private func profileMainContent(profile: PlayerProfile) -> some View {
        VStack(spacing: 22) {
            profileHeroImage(size: 120)
                .frame(maxWidth: .infinity, alignment: .center)

            usernameCapsule(profile: profile)

            statsRow(profile: profile)

            levelProgressSection(score: profile.totalScore)

            avatarPickerSection(score: profile.totalScore, allowAll: false)

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private func profileHeroImage(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
            Image(selectedAvatar)
                .resizable()
                .scaledToFit()
                .padding(size * 0.08)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3))
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
    }

    private var setupNameCapsule: some View {
        HStack {
            Spacer(minLength: 0)
            TextField("اسم السبوق", text: $setupName)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(Capsule())
                .frame(minWidth: 140, maxWidth: 220)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            Spacer(minLength: 0)
        }
    }

    private func usernameCapsule(profile: PlayerProfile) -> some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                if isEditing {
                    TextField("اسم السبوق", text: $editedUsername)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .frame(minWidth: 100, maxWidth: 160)

                    Button {
                        saveUsername()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.accent)
                    }

                    Button {
                        cancelEdit()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    Text(profile.username)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)

                    Button {
                        startEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            Spacer(minLength: 0)
        }
    }

    private func statsRow(profile: PlayerProfile) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(profile.totalScore)", title: "النقاط")
            Rectangle()
                .fill(AppTheme.textSecondary.opacity(0.25))
                .frame(width: 1, height: 44)
            statItem(value: "\(profile.totalGamesPlayed)", title: "شطور")
        }
        .padding(.vertical, 8)
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func statItem(value: String, title: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.black)
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func levelProgressSection(score: Int) -> some View {
        let level = ProfileLevel.currentLevel(score: score)
        let nextLevel = min(level + 1, ProfileLevel.maxLevel + 1)
        let threshold = ProfileLevel.nextThreshold(currentLevel: level)
        let progress = min(1.0, Double(score) / Double(threshold))

        return VStack(alignment: .center, spacing: 6) {
            Text("المستوى \(level)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 6) {
                levelBadge(number: nextLevel, filled: false)

                ZStack(alignment: .trailing) {
                    Capsule()
                        .fill(Color.white.opacity(0.55))
                    GeometryReader { barGeo in
                        Capsule()
                            .fill(AppTheme.accent)
                            .frame(width: max(0, barGeo.size.width * progress))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Text("\(score)/\(threshold)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                }
                .frame(height: 18)
                .frame(maxWidth: .infinity)

                levelBadge(number: level, filled: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func levelBadge(number: Int, filled: Bool) -> some View {
        Text("\(number)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(filled ? AppTheme.textPrimary : AppTheme.textSecondary)
            .frame(width: 22, height: 22)
            .background(filled ? AppTheme.accentSoft : Color.white.opacity(0.7))
            .clipShape(Circle())
    }

    private func avatarPickerSection(score: Int, allowAll: Bool) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text("اختر فارس الميدان :")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    Spacer(minLength: 0)
                    ForEach(Array((1...ProfileLevel.maxLevel).reversed()), id: \.self) { level in
                        let avatarName = PlayerAvatars.avatar(forLevel: level)
                        let unlocked = allowAll || ProfileLevel.isUnlocked(level: level, score: score)
                        AvatarLevelCard(
                            level: level,
                            avatarName: avatarName,
                            isSelected: selectedAvatar == avatarName,
                            isUnlocked: unlocked
                        ) {
                            guard unlocked else { return }
                            selectedAvatar = avatarName
                            if profileManager.currentProfile != nil {
                                profileManager.updateAvatar(avatarName)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var musicSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: audioManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.subheadline)
                    .foregroundColor(.black)
                Text("موسيقى الخلفية")
                    .font(.subheadline)
                    .foregroundColor(.black)
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { !audioManager.isMuted },
                        set: { audioManager.setMuted(!$0) }
                    )
                )
                .labelsHidden()
                .scaleEffect(0.85)
            }

            if !audioManager.isMuted {
                Slider(
                    value: Binding(
                        get: { Double(audioManager.volume) },
                        set: { audioManager.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Avatar Level Card
private struct AvatarLevelCard: View {
    let level: Int
    let avatarName: String
    let isSelected: Bool
    let isUnlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text("المستوى")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(level)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Image(avatarName)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .frame(width: 72, height: 72)
                    .opacity(isUnlocked ? 1 : 0.35)
            }
            .frame(width: 108, height: 148)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }
}

#Preview {
    ProfileView(profileManager: ProfileManager())
}

// MARK: - All Players Leaderboard View
struct AllPlayersLeaderboardView: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var allProfiles: [PlayerProfile] = []
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("التصنيف")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                
                if allProfiles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trophy")
                            .font(.system(size: 60))
                            .foregroundColor(.black)
                        Text("ما فيه لاعبون بعد")
                            .font(.title2)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        Text("العب عشان تشوف التصنيف")
                            .font(.caption)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else {
                    List {
                        ForEach(Array(allProfiles.enumerated()), id: \.element.id) { index, profile in
                            HStack(alignment: .center, spacing: 12) {
                                Text("#\(index + 1)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(width: 36, alignment: .center)

                                VStack(alignment: .center, spacing: 4) {
                                    Text(profile.username)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.center)
                                    HStack(spacing: 4) {
                                        Text("\(profile.totalGamesPlayed) لعبة")
                                        Text("•")
                                        Text("الأفضل: \(profile.bestScore)")
                                    }
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)

                                VStack(alignment: .center, spacing: 2) {
                                    Text("\(profile.bestScore)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("نقطة")
                                        .font(.caption)
                                }
                                .foregroundColor(.black)
                                .frame(width: 48, alignment: .center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                            .listRowBackground(index == 0 ? AppTheme.accentSoft.opacity(0.35) : AppTheme.surface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.black)
            .padding()
        }
        .environment(\.colorScheme, .light)
        .environment(\.layoutDirection, .leftToRight)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            allProfiles = profileManager.getAllProfiles()
        }
    }
}

//import SwiftUI
//import SwiftData
//
//struct ProfileView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Environment(\.dismiss) private var dismissProfile
//    @ObservedObject var profileManager: ProfileManager
//    @ObservedObject private var audioManager = BackgroundMusicManager.shared
//    private var showProfile: Binding<Bool>?
//    var onLogout: (() -> Void)?
//    @State private var isEditing: Bool = false
//    @State private var editedUsername: String = ""
//    
//    // ✅ جديد: للتحكم بالتنقل لصفحة UsernameEntryView
//    @State private var goToUsername: Bool = false
//    @State private var username: String = ""
//    @State private var showLobby: Bool = false
//    @State private var isHost: Bool = false
//    @StateObject private var multipeerService = MultipeerService()
//    
//    init(profileManager: ProfileManager, showProfile: Binding<Bool>? = nil, onLogout: (() -> Void)? = nil) {
//        self.profileManager = profileManager
//        self.showProfile = showProfile
//        self.onLogout = onLogout
//    }
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                Color(hex: "FDECC5").ignoresSafeArea()
//                
//                VStack(spacing: 30) {
//                    
//                    // ✅ NavigationLink مخفي للتنقل الطبيعي
//                    NavigationLink(
//                        destination: UsernameEntryView(
//                            username: $username,
//                            showLobby: $showLobby,
//                            isHost: $isHost,
//                            multipeerService: multipeerService
//                        ),
//                        isActive: $goToUsername
//                    ) {
//                        EmptyView()
//                    }
//                    .hidden()
//                    
//                    if let profile = profileManager.currentProfile {
//                        // Profile Header
//                        VStack(spacing: 15) {
//                            Image("profile")
//                                .font(.system(size: 80))
//                                .foregroundColor(.blue)
//                            
//                            if isEditing {
//                                TextField("Username", text: $editedUsername)
//                                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                                    .font(.title2)
//                                    .multilineTextAlignment(.center)
//                                    .padding(.horizontal, 40)
//                            } else {
//                                Text(profile.username)
//                                    .font(.title)
//                                    .fontWeight(.bold)
//                            }
//                            
//                            HStack(spacing: 20) {
//                                if isEditing {
//                                    Button("Save") {
//                                        saveUsername()
//                                    }
//                                    .buttonStyle(.borderedProminent)
//                                    
//                                    Button("Cancel") {
//                                        cancelEdit()
//                                    }
//                                    .buttonStyle(.bordered)
//                                } else {
//                                    Button("Edit Name") {
//                                        startEditing()
//                                    }
//                                    .buttonStyle(.bordered)
//                                }
//                            }
//                        }
//                        .padding(.top, 40)
//                        
//                        Divider()
//                        
//                        // Statistics
//                        VStack(spacing: 20) {
//                            Text("Statistics")
//                                .font(.title2)
//                                .fontWeight(.semibold)
//                            
//                            LazyVGrid(columns: [
//                                GridItem(.flexible()),
//                                GridItem(.flexible())
//                            ], spacing: 20) {
//                                StatCard(title: "Games Played", value: "\(profile.totalGamesPlayed)")
//                                StatCard(title: "Best Score", value: "\(profile.bestScore)")
//                                StatCard(title: "Total Score", value: "\(profile.totalScore)")
//                                StatCard(title: "Games Won", value: "\(profile.gamesWon)")
//                                StatCard(title: "Average Score", value: String(format: "%.1f", profile.averageScore))
//                                StatCard(
//                                    title: "Win Rate",
//                                    value: profile.totalGamesPlayed > 0
//                                    ? String(format: "%.1f%%", Double(profile.gamesWon) / Double(profile.totalGamesPlayed) * 100)
//                                    : "0%"
//                                )
//                        }
//                        .padding(.horizontal)
//                    }
//                    
//                    Divider()
//                    
//                    // Audio Settings
//                    VStack(spacing: 20) {
//                        Text("Audio Settings")
//                            .font(.title2)
//                            .fontWeight(.semibold)
//                        
//                        VStack(spacing: 15) {
//                            // Mute Toggle
//                            HStack {
//                                Image(systemName: audioManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
//                                    .font(.title3)
//                                    .foregroundColor(.blue)
//                                
//                                Text("Background Music")
//                                    .font(.headline)
//                                
//                                Spacer()
//                                
//                                Toggle("", isOn: Binding(
//                                    get: { !audioManager.isMuted },
//                                    set: { audioManager.setMuted(!$0) }
//                                ))
//                                .labelsHidden()
//                            }
//                            .padding(.horizontal, 20)
//                            
//                            // Volume Slider
//                            if !audioManager.isMuted {
//                                VStack(spacing: 8) {
//                                    HStack {
//                                        Image(systemName: "speaker.wave.1.fill")
//                                            .foregroundColor(.gray)
//                                        Slider(value: Binding(
//                                            get: { Double(audioManager.volume) },
//                                            set: { audioManager.setVolume(Float($0)) }
//                                        ), in: 0...1)
//                                        Image(systemName: "speaker.wave.3.fill")
//                                            .foregroundColor(.gray)
//                                    }
//                                    .padding(.horizontal, 20)
//                                    
//                                    Text("Volume: \(Int(audioManager.volume * 100))%")
//                                        .font(.caption)
//                                        .foregroundColor(.gray)
//                                }
//                            }
//                        }
//                        .padding(.vertical, 10)
//                        .background(Color.gray.opacity(0.1))
//                        .cornerRadius(10)
//                        .padding(.horizontal, 20)
//                    }
//                    .padding(.top, 10)
//                    
//                    // All Players Leaderboard
//                    NavigationLink(destination: AllPlayersView(profileManager: profileManager)) {
//                            HStack {
//                                Image(systemName: "trophy.fill")
//                                Text("View All Players")
//                            }
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.orange)
//                            .cornerRadius(10)
//                        }
//                        .padding(.horizontal, 40)
//                        .padding(.top, 20)
//                        
//                        Spacer()
//                    } else {
//                        Text("No profile found")
//                            .foregroundColor(.gray)
//                            .padding(.top, 100)
//                        
//                        Spacer()
//                    }
//                }
//                .padding()
//            }
//            .preferredColorScheme(.light)
//            .navigationTitle("My Profile")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("خروج") {
//                        profileManager.clearCurrentProfile()
//                        
//                        // Stop background music when logging out
//                        BackgroundMusicManager.shared.stopBackgroundMusic()
//                        
//                        // ✅ تنقل طبيعي (Navigation) إلى UsernameEntryView
//                        goToUsername = true
//                        
//                        // (اختياري) لو عندك من برا منطق تبغينه يشتغل
//                        onLogout?()
//                    }
//                }
//            }
//        }
//        .onAppear {
//            profileManager.setModelContext(modelContext)
//        }
//    }
//    
//    func startEditing() {
//        if let profile = profileManager.currentProfile {
//            editedUsername = profile.username
//            isEditing = true
//        }
//    }
//    
//    func cancelEdit() {
//        isEditing = false
//        editedUsername = ""
//    }
//    
//    func saveUsername() {
//        guard let profile = profileManager.currentProfile else { return }
//        guard !editedUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }
//        
//        profileManager.updateUsername(
//            oldUsername: profile.username,
//            newUsername: editedUsername.trimmingCharacters(in: .whitespaces)
//        )
//        isEditing = false
//    }
//}
//
//struct StatCard: View {
//    let title: String
//    let value: String
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            Text(value)
//                .font(.title2)
//                .fontWeight(.bold)
//                .foregroundColor(.blue)
//            Text(title)
//                .font(.caption)
//                .foregroundColor(.gray)
//        }
//        .frame(maxWidth: .infinity)
//        .padding()
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(10)
//    }
//}
//
//struct AllPlayersView: View {
//    @ObservedObject var profileManager: ProfileManager
//    @State private var allProfiles: [PlayerProfile] = []
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                Color(hex: "FDECC5").ignoresSafeArea()
//                List {
//                    ForEach(Array(allProfiles.enumerated()), id: \.element.id) { index, profile in
//                        HStack {
//                            Text("#\(index + 1)")
//                                .font(.title3)
//                                .fontWeight(.bold)
//                                .foregroundColor(getRankColor(index: index))
//                                .frame(width: 40)
//                            
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text(profile.username)
//                                    .font(.headline)
//                                Text("\(profile.totalGamesPlayed) games • Best: \(profile.bestScore)")
//                                    .font(.caption)
//                                    .foregroundColor(.gray)
//                            }
//                            
//                            Spacer()
//                            
//                            Text("\(profile.bestScore)")
//                                .font(.title3)
//                                .fontWeight(.semibold)
//                                .foregroundColor(getRankColor(index: index))
//                        }
//                        .padding(.vertical, 4)
//                    }
//                }
//            }
//            .navigationTitle("All Players")
//            .navigationBarTitleDisplayMode(.inline)
//            .preferredColorScheme(.light)
//        }
//        .onAppear {
//            allProfiles = profileManager.getAllProfiles()
//        }
//    }
//    
//    func getRankColor(index: Int) -> Color {
//        switch index {
//        case 0: return .yellow
//        case 1: return .gray
//        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
//        default: return .primary
//        }
//    }
//}
//
//#Preview {
//    ProfileView(
//        profileManager: ProfileManager()
//    )
//}

