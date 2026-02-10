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

    var onLogout: (() -> Void)?

    @State private var isEditing: Bool = false
    @State private var editedUsername: String = ""
    @State private var showLeaderboard: Bool = false
    @State private var navigateToUsernameEntry: Bool = false

    init(
        profileManager: ProfileManager,
        onLogout: (() -> Void)? = nil
    ) {
        self.profileManager = profileManager
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 30) {

                            // صورة البروفايل
                            Image("profile")
                                .resizable()
                                .scaledToFit()
                                .frame(height: min(geo.size.height * 0.22, 180))
                                .padding(.top, 20)

                            if let profile = profileManager.currentProfile {

                                // الاسم
                                if isEditing {
                                    TextField("Username", text: $editedUsername)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.title2)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                } else {
                                    Text(profile.username)
                                        .font(.title)
                                        .fontWeight(.bold)
                                }

                                // أزرار التعديل
                                HStack(spacing: 20) {
                                    if isEditing {
                                        Button("Save") {
                                            saveUsername()
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button("Cancel") {
                                            cancelEdit()
                                        }
                                        .buttonStyle(.bordered)
                                    } else {
                                        Button("Edit Name") {
                                            startEditing()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }

                                Divider()

                                // الإحصائيات
                                VStack(spacing: 20) {
                                    Text("Statistics")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible()),
                                            GridItem(.flexible())
                                        ],
                                        spacing: 20
                                    ) {
                                        StatCard(title: "Games Played", value: "\(profile.totalGamesPlayed)")
                                        StatCard(title: "Best Score", value: "\(profile.bestScore)")
                                        StatCard(title: "Total Score", value: "\(profile.totalScore)")
                                        StatCard(title: "Games Won", value: "\(profile.gamesWon)")
                                        StatCard(
                                            title: "Average Score",
                                            value: String(format: "%.1f", profile.averageScore)
                                        )
                                        StatCard(
                                            title: "Win Rate",
                                            value: profile.totalGamesPlayed > 0
                                                ? String(
                                                    format: "%.1f%%",
                                                    Double(profile.gamesWon) / Double(profile.totalGamesPlayed) * 100
                                                )
                                                : "0%"
                                        )
                                    }
                                }

                                Divider()

                                // Leaderboard Button
                                NavigationLink(destination: AllPlayersLeaderboardView(profileManager: profileManager)) { HStack {
                                        Image(systemName: "trophy.fill")
                                            .foregroundColor(AppTheme.textOnAccent)
                                        Text("Leaderboard")
                                            .font(.headline)
                                            .foregroundColor(AppTheme.textOnAccent)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppTheme.accent)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)

                                Divider()

                                // الصوت
                                VStack(spacing: 15) {
                                    HStack {
                                        Image(systemName: audioManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        Text("Background Music")
                                        Spacer()
                                        Toggle(
                                            "",
                                            isOn: Binding(
                                                get: { !audioManager.isMuted },
                                                set: { audioManager.setMuted(!$0) }
                                            )
                                        )
                                        .labelsHidden()
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
                                .padding()
                                .background(AppTheme.surface)
                                .cornerRadius(12)

                                Spacer(minLength: 40)

                            } else {
                                Text("No profile found")
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                        }
                        .frame(maxWidth: .infinity) // 👈 يناسب كل المقاسات
                        .padding()
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        profileManager.clearCurrentProfile()
                        BackgroundMusicManager.shared.stopBackgroundMusic()
                        dismiss()
                        navigateToUsernameEntry = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .onAppear {
                profileManager.setModelContext(modelContext)
            }
        }
        .fullScreenCover(isPresented: $navigateToUsernameEntry) {
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

    // MARK: - Stat Card
    struct StatCard: View {
        let title: String
        let value: String

        var body: some View {
            VStack(spacing: 8) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.surface)
            .cornerRadius(10)
        }
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
                    .padding(.top, 20)
                
                if allProfiles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trophy")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("No players yet")
                            .font(.title2)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Play games to see leaderboard")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(Array(allProfiles.enumerated()), id: \.element.id) { index, profile in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(getRankColor(index: index))
                                    .frame(width: 50)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.username)
                                        .font(.headline)
                                    Text(
                                        String(
                                            format: NSLocalizedString("%d games • Best: %d", comment: ""),
                                            profile.totalGamesPlayed,
                                            profile.bestScore
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(profile.bestScore)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(getRankColor(index: index))
                                    Text("pts")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(index < 3 ? getRankColor(index: index).opacity(0.1) : Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            allProfiles = profileManager.getAllProfiles()
        }
    }
    
    func getRankColor(index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .primary
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

