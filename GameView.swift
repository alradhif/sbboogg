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
                let cameraHeight = min(geo.size.height * 0.55, 520)
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
        case "glasses": return "نظارة!"
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

#Preview {
    GameView(
        gameManager: GameManager(multipeerService: MultipeerService()),
        multipeerService: MultipeerService()
    )
}
