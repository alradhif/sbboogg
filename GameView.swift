//
//  GameView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import UIKit

struct GameView: View {
    @ObservedObject var gameManager: GameManager
    @ObservedObject var multipeerService: MultipeerService
    var onExitGame: () -> Void

    @StateObject private var visionClassifier = VisionClassifier()

    @State private var capturedImage: UIImage?
    @State private var classificationResult: String?
    @State private var isImageCaptured: Bool = false
    @State private var showLeaderboard: Bool = false
    @State private var hasReportedFind: Bool = false
    @State private var objectFoundByOthers: String? = nil
    @State private var lastClassificationWasSuccess: Bool? = nil
    @State private var captureTrigger: Bool = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            GeometryReader { geo in
                let cameraHeight = min(geo.size.height * 0.46, 440)
                let targetName = gameManager.currentChallenge?.objectName ?? NSLocalizedString("العنصر", comment: "")

                VStack(spacing: 16) {
                    HStack {
                        GameExitConfirmButton(onConfirm: exitFromGame)

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

                            if visionClassifier.isClassifying {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.black.opacity(0.45))
                                    .frame(height: cameraHeight)
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                    Text("جاري التحقق…")
                                        .font(.appHeadline)
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            CameraPreviewView(
                                capturedImage: $capturedImage,
                                classificationResult: $classificationResult,
                                isImageCaptured: $isImageCaptured,
                                captureTrigger: $captureTrigger,
                                isLiveDetectionEnabled: !isImageCaptured,
                                visionClassifier: visionClassifier,
                                targetObject: gameManager.currentChallenge?.objectName ?? "",
                                onObjectFound: { found, confidence, detail in
                                    handleObjectFound(found: found, confidence: confidence, detail: detail)
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
                            .disabled(visionClassifier.isClassifying)
                            .opacity(visionClassifier.isClassifying ? 0.5 : 1)
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
                        myPeerID: gameManager.myPlayerKey
                    )
                    .padding(.horizontal, 20)

                    if let result = classificationResult {
                        Text(result)
                            .font(.appHeadline)
                            .foregroundColor(lastClassificationWasSuccess == true ? AppTheme.accent : AppTheme.error)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                (lastClassificationWasSuccess == true ? AppTheme.accent : AppTheme.error)
                                    .opacity(0.12)
                            )
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: gameManager.currentRound) { _, _ in
            visionClassifier.cancelPending()
            resetCamera(immediate: true)
        }
        .onChange(of: gameManager.gameEnded) { ended in
            if ended { showLeaderboard = true }
        }
        .fullScreenCover(isPresented: $showLeaderboard) {
            LeaderboardView(
                gameManager: gameManager,
                multipeerService: multipeerService,
                onExitGame: onExitGame
            )
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

    func handleObjectFound(found: Bool, confidence: Double, detail: String) {
        guard !hasReportedFind else { return }
        guard let challenge = gameManager.currentChallenge else { return }

        lastClassificationWasSuccess = found
        classificationResult = found ? "✅ \(detail)" : "❌ \(detail)"

        if found {
            hasReportedFind = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if let room = gameManager.onlineRoom {
                Task { @MainActor in
                    let points = await room.submitFind(label: challenge.objectName, confidence: confidence)
                    if let points {
                        classificationResult = "صح! \(arabicName(for: challenge.objectName)) +\(points) نقطة"
                    } else {
                        classificationResult = "الشوط خلص قبل ما توصل لقطتك."
                    }
                }
                return
            }
            let points = gameManager.submitObjectFound(found: true, confidence: confidence) ?? 0
            classificationResult = "صح! \(arabicName(for: challenge.objectName))\n\(detail)\n+\(points) نقطة"
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            classificationResult = "مو صحيح.\n\(detail)\nجربي تصوير \(arabicName(for: challenge.objectName)) أوضح."
        }
    }

    private func exitFromGame() {
        multipeerService.stop()
        BackgroundMusicManager.shared.stopBackgroundMusic()
        if let room = gameManager.onlineRoom {
            Task { await room.leave() }
        }
        onExitGame()
    }

    func resetCamera(immediate: Bool = false) {
        let apply = {
            capturedImage = nil
            classificationResult = nil
            isImageCaptured = false
            hasReportedFind = false
            objectFoundByOthers = nil
            lastClassificationWasSuccess = nil
        }
        if immediate {
            apply()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                apply()
            }
        }
    }
}

#Preview {
    GameView(
        gameManager: GameManager(multipeerService: MultipeerService()),
        multipeerService: MultipeerService(),
        onExitGame: {}
    )
}
