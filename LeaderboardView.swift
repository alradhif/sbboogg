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
    @State private var navigateToUsernameEntry = false
    @State private var animateHero = false
    @Environment(\.dismiss) private var dismiss

    private var winner: Player? {
        gameManager.leaderboard.first
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

    private var headerBar: some View {
        HStack {
            Button {
                goToUsernameEntry()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

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

            RaceFinishView(
                players: gameManager.leaderboard,
                myUsername: multipeerService.username
            )
            .padding(.top, 12)
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

            RaceFinishView(
                players: gameManager.leaderboard,
                myUsername: multipeerService.username
            )
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

    private func goToUsernameEntry() {
        multipeerService.stop()
        BackgroundMusicManager.shared.stopBackgroundMusic()
        navigateToUsernameEntry = true
    }
}

/// The final standings drawn as a camel race: each player runs up their own
/// lane, and the winner reaches the finish line at the top.
struct RaceFinishView: View {
    /// Final standings, best score first.
    let players: [Player]
    let myUsername: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    private let trackHeight: CGFloat = 240
    private let tokenSize: CGFloat = 46

    private var topScore: Int {
        players.map(\.score).max() ?? 0
    }

    private var ranks: [String: Int] {
        var result: [String: Int] = [:]
        for (index, player) in players.enumerated() {
            // Players on the same score share a rank
            if index > 0, players[index - 1].score == player.score {
                result[player.username] = result[players[index - 1].username]
            } else {
                result[player.username] = index + 1
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("خط النهاية")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.bottom, 6)

            finishLine
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            HStack(alignment: .top, spacing: 8) {
                let rankMap = ranks
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    lane(
                        for: player,
                        rank: rankMap[player.username] ?? index + 1,
                        delay: Double(index) * 0.15
                    )
                }
            }
            // Winner on the right, the way the rest of the app reads
            .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFE7B0"), Color(hex: "F3CF8A")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
        .padding(.horizontal, 24)
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                progress = 0
                withAnimation(.spring(response: 1.6, dampingFraction: 0.85).delay(0.4)) {
                    progress = 1
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func lane(for player: Player, rank: Int, delay: Double) -> some View {
        let isMe = player.username == myUsername
        let fraction: CGFloat = topScore > 0
            ? CGFloat(player.score) / CGFloat(topScore)
            : 0
        let travel = (trackHeight - tokenSize) * fraction * progress

        return VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                // Lane marking
                Rectangle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)

                token(for: player, rank: rank, isMe: isMe)
                    .offset(y: -travel)
                    .animation(
                        reduceMotion ? nil : .spring(response: 1.6, dampingFraction: 0.85).delay(delay),
                        value: progress
                    )
            }
            .frame(height: trackHeight)
            .frame(maxWidth: .infinity)

            Text(player.username)
                .font(.system(size: 13, weight: isMe ? .heavy : .semibold))
                .foregroundColor(isMe ? AppTheme.accent : AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("\(Self.arabicNumeral(player.score)) نقطة")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textPrimary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func token(for player: Player, rank: Int, isMe: Bool) -> some View {
        Image(player.avatarImageName)
            .resizable()
            .scaledToFill()
            .frame(width: tokenSize, height: tokenSize)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(isMe ? Color.green : Color.white, lineWidth: isMe ? 3 : 2)
            )
            .overlay(alignment: .top) {
                Text(rank == 1 ? "👑" : Self.arabicNumeral(rank))
                    .font(.system(size: rank == 1 ? 18 : 12, weight: .heavy))
                    .foregroundColor(AppTheme.accent)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(rank == 1 ? Color.clear : Color.white)
                    .clipShape(Circle())
                    .offset(y: -14)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 3, y: 2)
    }

    private var finishLine: some View {
        Canvas { context, size in
            let square: CGFloat = 6
            let columns = Int(ceil(size.width / square))
            let rows = Int(ceil(size.height / square))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * square,
                        y: CGFloat(row) * square,
                        width: square,
                        height: square
                    )
                    context.fill(Path(rect), with: .color(AppTheme.textPrimary))
                }
            }
        }
        .background(Color.white)
    }

    private var accessibilitySummary: String {
        let rankMap = ranks
        return players
            .map { "\($0.username): المركز \(rankMap[$0.username] ?? 0)، \($0.score) نقطة" }
            .joined(separator: "، ")
    }

    private static func arabicNumeral(_ value: Int) -> String {
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
        multipeerService: MultipeerService()
    )
    .modelContainer(
        for: [Player.self, GameSession.self, PlayerProfile.self],
        inMemory: true
    )
}
