//
//  GameView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI

struct GameView: View {
    @ObservedObject var gameManager: GameManager
    @ObservedObject var multipeerService: MultipeerService

    // ✅ بدل CoreML
    @StateObject private var visionClassifier = VisionClassifier()

    @State private var capturedImage: UIImage?
    @State private var classificationResult: String?
    @State private var isImageCaptured: Bool = false
    @State private var showResult: Bool = false
    @State private var resultMessage: String = ""
    @State private var showLeaderboard: Bool = false
    @State private var hasReportedFind: Bool = false
    @State private var objectFoundByOthers: String? = nil
    @State private var lastClassificationWasSuccess: Bool? = nil
    @State private var captureTrigger: Bool = false
    @State private var navigateToUsernameEntry: Bool = false
    @Environment(\.dismiss) var dismissGameView

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            GeometryReader { geo in
                let cameraHeight = min(geo.size.height * 0.46, 440)
                let targetName = gameManager.currentChallenge?.objectName ?? NSLocalizedString("العنصر", comment: "")

                VStack(spacing: 16) {
                    HStack {
                        Button {
                            multipeerService.stop()
                            BackgroundMusicManager.shared.stopBackgroundMusic()
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

                        Spacer()
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ابحث عن :")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textPrimary)

                            Text(arabicName(for: targetName))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(AppTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ZStack(alignment: .topLeading) {
                            Image("cml")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70, height: 120)

                            Text("\(gameManager.timeRemaining)s")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textOnAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
                                .offset(x: -6, y: -6)
                        }
                    }
                    .padding(.horizontal, 24)

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.black)
                            .frame(height: cameraHeight)

                        if isImageCaptured, let image = capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: cameraHeight)
                                .cornerRadius(22)
                        } else {
                            CameraPreviewView(
                                capturedImage: $capturedImage,
                                classificationResult: $classificationResult,
                                isImageCaptured: $isImageCaptured,
                                captureTrigger: $captureTrigger,
                                visionClassifier: visionClassifier,
                                targetObject: gameManager.currentChallenge?.objectName ?? "",
                                onObjectFound: { found, confidence in
                                    handleObjectFound(found: found, confidence: confidence)
                                }
                            )
                            .frame(height: cameraHeight)
                            .cornerRadius(22)
                            .clipped()
                        }

                        HStack {
                            Button("إعادة") {
                                resetCamera()
                            }
                            .font(.appHeadline)
                            .foregroundColor(.white)

                            Spacer()

                            Button {
                                captureTrigger = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 64, height: 64)
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 50, height: 50)
                                }
                            }
                            .accessibilityLabel(NSLocalizedString("Capture", comment: ""))

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)

                    RaceTrackView(
                        players: gameManager.players,
                        maxScore: gameManager.maxPossibleScore,
                        myPeerID: multipeerService.myPeerID.displayName
                    )
                    .padding(.horizontal, 20)

                    if let result = classificationResult, lastClassificationWasSuccess == false {
                        Text("جرب مرة اخرى!")
                            .font(.appHeadline)
                            .foregroundColor(AppTheme.error)
                            .padding()
                            .background(AppTheme.error.opacity(0.1))
                            .cornerRadius(10)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Result", isPresented: $showResult) {
            Button("OK") {
                showResult = false
                resetCamera()
            }
        } message: {
            Text(resultMessage)
        }
        .onChange(of: gameManager.gameEnded) { ended in
            if ended { showLeaderboard = true }
        }
        .fullScreenCover(isPresented: $showLeaderboard) {
            LeaderboardView(gameManager: gameManager, multipeerService: multipeerService)
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
        .onAppear {
            BackgroundMusicManager.shared.startBackgroundMusic()
        }
    }

    func arabicName(for objectName: String) -> String {
        let languageCode = Locale.current.language.languageCode?.identifier ?? Locale.current.languageCode
        if languageCode == "en" {
            return objectName
        }
        switch objectName.lowercased() {
        case "book": return "كتاب!"
        case "water bottle": return "علبة موية!"
        case "phone", "mobile", "smartphone": return "جوال!"
        case "cup", "mug": return "كوب!"
        case "bag", "backpack", "handbag": return "شنطة!"
        case "shoes", "sneakers", "sports shoes": return "جزمه رياضيه!"
        case "pen": return "قلم!"
        case "watch": return "ساعة!"
        case "keys": return "مفاتيح!"
        default: return objectName
        }
    }

    func handleObjectFound(found: Bool, confidence: Double) {
        guard !hasReportedFind else { return }
        guard let challenge = gameManager.currentChallenge else { return }

        lastClassificationWasSuccess = found
        if found {
            hasReportedFind = true
            let points = gameManager.submitObjectFound(found: true, confidence: confidence) ?? 0
            resultMessage = String(
                format: NSLocalizedString("Found %@! +%d points", comment: ""),
                challenge.objectName,
                points
            )
            showResult = true
        } else {
            resultMessage = NSLocalizedString("That's not the right object. Try again!", comment: "")
            showResult = true
        }
    }

    func resetCamera() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            capturedImage = nil
            classificationResult = nil
            isImageCaptured = false
            hasReportedFind = false
            objectFoundByOthers = nil
            lastClassificationWasSuccess = nil
        }
    }
}

// MARK: - Live race track

/// Each player's camel runs toward the finish line as their score grows.
/// Scores already reach every device through the host's answer and
/// leaderboard messages, so this view only reads `gameManager.players`.
struct RaceTrackView: View {
    let players: [Player]
    let maxScore: Int
    let myPeerID: String

    @State private var lastScores: [String: Int] = [:]
    @State private var gains: [String: Int] = [:]

    private let laneHeight: CGFloat = 26
    private let tokenSize: CGFloat = 26
    private let edgeInset: CGFloat = 24

    private var scoreSignature: String {
        players.map { "\($0.username):\($0.score)" }.joined(separator: ",")
    }

    private var ranks: [String: Int] {
        let sorted = players.sorted { $0.score > $1.score }
        var result: [String: Int] = [:]
        for (index, player) in sorted.enumerated() {
            // Players on the same score share a rank
            if index > 0, sorted[index - 1].score == player.score {
                result[player.username] = result[sorted[index - 1].username]
            } else {
                result[player.username] = index + 1
            }
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let finishX = edgeInset
            let startX = geo.size.width - edgeInset
            let rankMap = ranks

            ZStack {
                LinearGradient(
                    colors: [Color(hex: "FFE7B0"), Color(hex: "F3CF8A")],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(players.indices, id: \.self) { index in
                    Path { path in
                        let y = laneY(index)
                        path.move(to: CGPoint(x: finishX, y: y))
                        path.addLine(to: CGPoint(x: startX, y: y))
                    }
                    .stroke(AppTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }

                finishLine
                    .frame(width: 8, height: geo.size.height)
                    .position(x: finishX, y: geo.size.height / 2)

                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    let progress = min(1, CGFloat(player.score) / CGFloat(max(maxScore, 1)))
                    token(for: player, rank: rankMap[player.username] ?? index + 1)
                        .position(
                            x: startX - (startX - finishX) * progress,
                            y: laneY(index)
                        )
                        .animation(.spring(response: 0.55, dampingFraction: 0.6), value: player.score)
                }
            }
        }
        .frame(height: CGFloat(max(players.count, 1)) * laneHeight + 12)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            lastScores = Dictionary(players.map { ($0.username, $0.score) }, uniquingKeysWith: { first, _ in first })
        }
        .onChange(of: scoreSignature) { _, _ in
            showGains()
        }
    }

    private func laneY(_ index: Int) -> CGFloat {
        6 + laneHeight * (CGFloat(index) + 0.5)
    }

    private var finishLine: some View {
        VStack(spacing: 0) {
            ForEach(0..<40, id: \.self) { row in
                HStack(spacing: 0) {
                    Rectangle().fill(row.isMultiple(of: 2) ? AppTheme.textPrimary : Color.white)
                    Rectangle().fill(row.isMultiple(of: 2) ? Color.white : AppTheme.textPrimary)
                }
                .frame(height: 4)
            }
        }
    }

    private func token(for player: Player, rank: Int) -> some View {
        let isMe = player.peerID == myPeerID
        return Image(player.avatarImageName)
            .resizable()
            .scaledToFit()
            .frame(width: tokenSize, height: tokenSize)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(isMe ? AppTheme.success : AppTheme.accent, lineWidth: 2))
            .overlay(alignment: .topLeading) {
                Text(Self.arabicNumeral(rank))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 14, height: 14)
                    .background(AppTheme.accentSoft)
                    .clipShape(Circle())
                    .offset(x: -5, y: -5)
            }
            .overlay(alignment: .top) {
                if let gain = gains[player.username] {
                    Text("+\(Self.arabicNumeral(gain))")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .background(AppTheme.success)
                        .clipShape(Capsule())
                        .environment(\.layoutDirection, .rightToLeft)
                        .offset(y: -18)
                        .transition(.scale.combined(with: .opacity))
                }
            }
    }

    private func showGains() {
        for player in players {
            let previous = lastScores[player.username] ?? 0
            let gain = player.score - previous
            guard gain > 0 else { continue }
            let username = player.username
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                gains[username] = gain
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    _ = gains.removeValue(forKey: username)
                }
            }
        }
        lastScores = Dictionary(players.map { ($0.username, $0.score) }, uniquingKeysWith: { first, _ in first })
    }

    private var accessibilitySummary: String {
        players
            .sorted { $0.score > $1.score }
            .map { "\($0.username) \($0.score)" }
            .joined(separator: "، ")
    }

    private static func arabicNumeral(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview {
    GameView(
        gameManager: GameManager(multipeerService: MultipeerService()),
        multipeerService: MultipeerService()
    )
}
