//
//  LeaderboardView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import SwiftData
import AVFoundation

struct LeaderboardView: View {
    @ObservedObject var gameManager: GameManager
    @ObservedObject var multipeerService: MultipeerService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var profileManager = ProfileManager()
    @State private var showProfile = false
    @State private var navigateToUsernameEntry = false
    @Environment(\.dismiss) var dismiss
    
    // ⭐️ هل اللاعب فائز؟
    @State private var isWinner: Bool = false
    @State private var animate: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                GeometryReader { geo in
                    let heroWidth = min(geo.size.width * 0.9, 420)
                    let heroHeight = min(geo.size.height * 0.25, 220)
                    VStack(spacing: 30) {
                    
                    // ⭐️ صورة الفائز / الخاسر مع الأنيميشن
                    if isWinner {
                        ZStack {
                            // صورة winnerRed في الخلفية
                            Image("winnerImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: heroWidth, height: heroHeight)
                                .offset(y: -20)
                            
                            // صورة winner مع الأنيميشن
                            Image("winnerImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: heroWidth * 0.55, height: heroHeight * 1.2)
                                .shadow(radius: 10)
                                .rotation3DEffect(
                                    Angle(degrees: animate ? 180 : 0),
                                    axis: (x: 0.0, y: 1.0, z: 0.0)
                                )
                                .onAppear {
                                    withAnimation(.interpolatingSpring(stiffness: 30, damping: 3).repeatForever()) {
                                        animate.toggle()
                                    }
                                }
                        }
                        .padding(.top, 20)
                    } else {
                        ZStack {
                            // صورة لاعب في الخلفية
                            Image("لاعب")
                                .resizable()
                                .scaledToFit()
                                .frame(width: heroWidth, height: heroHeight)
                                .offset(y: -20)
                            
                            // صورة loser مع الأنيميشن
                            Image("loserImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: heroWidth * 0.6, height: heroHeight * 1.3)
                                .shadow(radius: 10)
                                .rotation3DEffect(
                                    Angle(degrees: animate ? 180 : 0),
                                    axis: (x: 0.0, y: 1.0, z: 0.0)
                                )
                                .onAppear {
                                    withAnimation(.interpolatingSpring(stiffness: 30, damping: 3).repeatForever()) {
                                        animate.toggle()
                                    }
                                }
                        }
                        .padding(.top, 20)
                    }
                    
                    Text("النتائج النهائية")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 10)
                    
                    Text("التصنيف")
                        .font(.title2)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    if gameManager.leaderboard.isEmpty {
                        Text("لايوجد نتائج")
                            .foregroundColor(AppTheme.textSecondary)
                            .padding()
                    } else {
                        List {
                            ForEach(Array(gameManager.leaderboard.enumerated()), id: \.element.id) { index, player in
                                HStack {
                                    
                                    // Rank
                                    Text("#\(index + 1)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(getRankColor(index: index))
                                        .frame(width: 50)
                                    
                                    // Player name
                                    VStack(alignment: .leading) {
                                        Text(player.username)
                                            .font(.headline)
                                        if player.isHost {
                                            Text("Host")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.accent)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Score
                                    Text(String(format: NSLocalizedString("%d pts", comment: ""), player.score))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(getRankColor(index: index))
                                }
                                .padding(.vertical, 8)
                                .listRowBackground(index == 0 ? Color.yellow.opacity(0.2) : Color.clear)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                    
                    Button(action: {
                        multipeerService.stop()
                        profileManager.setModelContext(modelContext)
                        // Stop background music when going back
                        BackgroundMusicManager.shared.stopBackgroundMusic()
                        showProfile = true
                    }) {
                        Text("عودة للبداية")
                            .font(.headline)
                            .foregroundColor(AppTheme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.accent)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                    .padding()
                    .frame(minHeight: geo.size.height)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            profileManager.setModelContext(modelContext)
            checkIfWinner()
            
            // Ensure background music continues playing
            BackgroundMusicManager.shared.startBackgroundMusic()
            
            // تشغيل الصوت حسب النتيجة
            if isWinner {
                SoundManager.playSound(sound: "winner", type: "mp3")
            } else {
                SoundManager.playSound(sound: "loser", type: "mp3")
            }
        }
        .onDisappear {
            // إيقاف الصوت عند الخروج
            SoundManager.stopAudio()
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileView(
                profileManager: profileManager,
                onLogout: {
                    // Close ProfileView first
                    showProfile = false
                    // Set navigateToUsernameEntry before dismissing
                    navigateToUsernameEntry = true
                    // Then dismiss LeaderboardView after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            )
        }
        .onChange(of: showProfile) { oldValue, newValue in
            // When profile sheet is dismissed, check if profile was cleared
            if oldValue == true && newValue == false {
                if profileManager.currentProfile == nil {
                    // Profile was cleared, navigate to UsernameEntryView
                    navigateToUsernameEntry = true
                    // Then dismiss LeaderboardView after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
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
    
    // ⭐️ التحقق من الفوز
    func checkIfWinner() {
        guard !multipeerService.username.isEmpty else { return }
        
        if let firstPlayer = gameManager.leaderboard.first {
            isWinner = (firstPlayer.username == multipeerService.username)
        }
    }
    
    func getRankColor(index: Int) -> Color {
        switch index {
        case 0:
            return .yellow
        case 1:
            return .gray
        case 2:
            return Color(red: 0.8, green: 0.5, blue: 0.2)
        default:
            return .primary
        }
    }
}

// SoundManager class
class SoundManager {
    static var audioPlayer: AVAudioPlayer?

    static func playSound(sound: String, type: String) {
        if let path = Bundle.main.path(forResource: sound, ofType: type) {
            do {
                BackgroundMusicManager.shared.stopBackgroundMusic()
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                audioPlayer?.play()
            } catch {
                print("Error playing sound: \(error.localizedDescription)")
            }
        }
    }

    static func stopAudio() {
        audioPlayer?.stop()
    }
}

#Preview {
    LeaderboardView(
        gameManager: GameManager(multipeerService: MultipeerService()),
        multipeerService: MultipeerService()
    )
    .modelContainer(
        for: [Player.self, GameSession.self, PlayerProfile.self],
        inMemory: true
    )
}
