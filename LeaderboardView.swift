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
    var onExitGame: () -> Void
    @Environment(\.modelContext) private var modelContext
    @StateObject private var profileManager = ProfileManager()
    @State private var animateHero = false

    private var winner: Player? {
        gameManager.leaderboard.first
    }

    private var runnersUp: [Player] {
        Array(gameManager.leaderboard.dropFirst())
    }

    private var currentPlayer: Player? {
        gameManager.leaderboard.first(where: { $0.username == multipeerService.username })
    }

    private var currentPlayerRank: Int? {
        gameManager.leaderboard.firstIndex(where: { $0.username == multipeerService.username }).map { $0 + 1 }
    }

    private var displayNameForLoser: String? {
        if let username = currentPlayer?.username {
            return username
        }
        let username = multipeerService.username
        return username.isEmpty ? nil : username
    }

    private var userIsWinner: Bool {
        guard !multipeerService.username.isEmpty,
              let first = gameManager.leaderboard.first else { return false }
        return first.username == multipeerService.username
    }

    var body: some View {
        ZStack {
            Color(hex: userIsWinner ? "FFE4A0" : "C1BAA9")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if userIsWinner {
                        winnerContent
                    } else {
                        loserContent
                    }

                    Button {
                        goToUsernameEntry()
                    } label: {
                        Text("شوط جديد")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            profileManager.setModelContext(modelContext)
            BackgroundMusicManager.shared.startBackgroundMusic()

            if userIsWinner {
                SoundManager.playSound(sound: "winner", type: "mp3")
            } else {
                SoundManager.playSound(sound: "loser", type: "mp3")
            }
        }
        .onDisappear {
            SoundManager.stopAudio()
        }
    }

    private var headerBar: some View {
        HStack {
            GameExitConfirmButton(onConfirm: goToUsernameEntry)
            Spacer()
        }
    }

    private func styledTitle(_ text: String, size: CGFloat = 50) -> some View {
        Text(text)
            .font(.appTitle(size))
            .foregroundColor(AppTheme.textPrimary)
            .overlay(
                Text(text)
                    .font(.appTitle(size))
                    .foregroundColor(AppTheme.accent)
                    .offset(x: 1, y: 1)
            )
            .rotationEffect(.degrees(-7))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    private var sabouqTitle: some View {
        styledTitle("سـبٌوق")
    }

    private var maoudKhairTitle: some View {
        styledTitle("معوض خير", size: 44)
    }

    private func animatedHeroImage(name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280, maxHeight: 240)
            .shadow(radius: 10)
            .rotation3DEffect(
                Angle(degrees: animateHero ? 180 : 0),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .padding(.top, 8)
            .onAppear {
                animateHero = false
                withAnimation(.interpolatingSpring(stiffness: 30, damping: 3).repeatForever()) {
                    animateHero.toggle()
                }
            }
    }

    private var winnerContent: some View {
        Group {
            sabouqTitle

            animatedHeroImage(name: "winnerImage")

            if let winner {
                winnerBanner(name: winner.username)
                    .padding(.top, 4)
            }

            rankingsList(players: runnersUp, startRank: 2)
        }
    }

    private var loserContent: some View {
        Group {
            maoudKhairTitle

            animatedHeroImage(name: "loserImage")

            if let winner {
                winnerBanner(name: winner.username)
                    .padding(.top, 4)
            }

            if let name = displayNameForLoser, let rank = currentPlayerRank, rank > 1 {
                loserRankRow(name: name, rank: rank)
                    .padding(.top, 12)
            }
        }
    }

    private func loserRankRow(name: String, rank: Int) -> some View {
        HStack(spacing: 16) {
            Text(name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            ZStack {
                Circle()
                    .fill(Color(hex: "FFF5E3"))
                    .frame(width: 50, height: 50)
                Text(arabicNumeral(rank))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func rankingsList(players: [Player], startRank: Int) -> some View {
        if players.isEmpty {
            Text("لايوجد نتائج")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, 12)
        } else {
            VStack(spacing: 18) {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    runnerUpRow(player: player, rank: startRank + index)
                }
            }
            .padding(.top, 12)
        }
    }

    private func winnerBanner(name: String) -> some View {
        nameRibbonBanner(name: name)
    }

    private func nameRibbonBanner(name: String) -> some View {
        ZStack {
            Image("Ribbon")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 80)

            Text(name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 28)
                .offset(y: -12)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }

    private func runnerUpRow(player: Player, rank: Int) -> some View {
        HStack(spacing: 16) {
            Text(player.username)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            ZStack {
                Circle()
                    .fill(Color(hex: "FFF5E3"))
                    .frame(width: 50, height: 50)
                Text(arabicNumeral(rank))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func goToUsernameEntry() {
        SoundManager.stopAudio()
        multipeerService.stop()
        BackgroundMusicManager.shared.stopBackgroundMusic()
        onExitGame()
    }

    private func arabicNumeral(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
        multipeerService: MultipeerService(),
        onExitGame: {}
    )
    .modelContainer(
        for: [Player.self, GameSession.self, PlayerProfile.self],
        inMemory: true
    )
}
