//
//  OnlineRoomView.swift
//  sbog
//
//  Play with friends who aren't in the same room: create a room and share its
//  code, or join with a friend's code. The game itself reuses GameView.
//

import SwiftUI
import SwiftData

struct OnlineRoomView: View {
    let username: String
    let avatarImageName: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared
    @StateObject private var room = OnlineRoom()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var multipeerService: MultipeerService
    @StateObject private var gameManager: GameManager
    @State private var codeInput = ""
    @State private var showGame = false
    @State private var pendingRoomAction: PendingRoomAction?
    @FocusState private var codeFieldFocused: Bool

    private enum PendingRoomAction {
        case create, join
    }

    init(username: String, avatarImageName: String) {
        self.username = username
        self.avatarImageName = avatarImageName
        let service = MultipeerService()
        _multipeerService = StateObject(wrappedValue: service)
        _gameManager = StateObject(wrappedValue: GameManager(multipeerService: service))
    }

    private var displayUsername: String {
        let fromProp = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if fromProp.count >= 2 { return fromProp }
        let fromProfile = profileManager.currentProfile?.username.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fromProfile.count >= 2 ? fromProfile : fromProp
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 4)

                Group {
                    if room.roomID != nil {
                        ScrollView {
                            lobby
                                .padding(.horizontal, 28)
                                .padding(.vertical, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                if auth.state == .loading {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text("جاري الاتصال…")
                                            .font(.appBody)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                if auth.state == .signedOut {
                                    SignInOptionsView()
                                }

                                createOrJoin
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 10)
                            .padding(.bottom, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let message = room.errorMessage ?? auth.errorMessage {
                    Text(message)
                        .font(.appCaption)
                        .foregroundColor(AppTheme.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            room.gameManager = gameManager
            gameManager.onlineRoom = room
            profileManager.setModelContext(modelContext)
            gameManager.setProfileManager(profileManager)
            multipeerService.username = displayUsername
            multipeerService.avatarImageName = PlayerAvatars.imageName(for: avatarImageName)
            Task { await auth.prepareForOnlinePlay() }
        }
        .onChange(of: room.status) { status in
            if status == "playing" && !showGame {
                BackgroundMusicManager.shared.startBackgroundMusic()
                showGame = true
            }
        }
        .onChange(of: auth.state) { state in
            if state == .signedOut, room.roomID != nil {
                Task { await room.leave() }
            }
        }
        .fullScreenCover(isPresented: $showGame) {
            GameView(
                gameManager: gameManager,
                multipeerService: multipeerService,
                onExitGame: {
                    showGame = false
                    BackgroundMusicManager.shared.stopBackgroundMusic()
                    Task { await room.leave() }
                }
            )
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button {
                Task {
                    await room.leave()
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
            }
            Spacer()
            Text("العب أونلاين")
                .font(.appTitle(26))
                .foregroundColor(AppTheme.accent)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var createOrJoin: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("كود الغرفة")
                    .font(.appHeadline)
                    .foregroundColor(AppTheme.textPrimary)

                Text("٥ أحرف أو أرقام (إنجليزي — مثل AB12C)")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)

                RoomCodeField(code: $codeInput)
                    .focused($codeFieldFocused)
                    .onSubmit { tryJoin() }
            }

            primaryButton(
                "ادخل",
                filled: true,
                isLoading: pendingRoomAction == .join && room.isWorking
            ) {
                tryJoin()
            }
            .disabled(codeInput.count < 5 || room.isWorking || pendingRoomAction != nil)
            .opacity(codeInput.count < 5 ? 0.5 : 1)

            Text("أو")
                .font(.appCaption)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.top, 4)

            Image("camel")
                .resizable()
                .scaledToFit()
                .frame(height: 88)

            primaryButton(
                "سوّ غرفة وادعِ ربعك",
                filled: false,
                isLoading: pendingRoomAction == .create && room.isWorking
            ) {
                guard pendingRoomAction == nil, !room.isWorking else { return }
                pendingRoomAction = .create
                Task {
                    await auth.prepareForOnlinePlay()
                    await room.create(username: displayUsername, avatarImageName: avatarImageName)
                    pendingRoomAction = nil
                }
            }
            .disabled(room.isWorking || pendingRoomAction != nil)
        }
    }

    private func tryJoin() {
        guard codeInput.count == 5, pendingRoomAction == nil, !room.isWorking else { return }
        codeFieldFocused = false
        pendingRoomAction = .join
        Task {
            await auth.prepareForOnlinePlay()
            await room.join(code: codeInput, username: displayUsername, avatarImageName: avatarImageName)
            pendingRoomAction = nil
        }
    }

    private var lobby: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("كود الغرفة")
                    .font(.appCaption)
                    .foregroundColor(AppTheme.textSecondary)
                Text(room.code)
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
                    .kerning(6)
                ShareLink(item: "تعال نلعب سبوق! ادخل الكود \(room.code) في «العب أونلاين»") {
                    Label("أرسل الكود لربعك", systemImage: "square.and.arrow.up")
                        .font(.appHeadline)
                        .foregroundColor(AppTheme.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 0) {
                ForEach(room.activePlayers) { player in
                    HStack(spacing: 12) {
                        Image(PlayerAvatars.imageName(for: player.profile.avatarImageName))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        Text(player.profile.username)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        if player.playerID == room.myID {
                            Text("(أنت)")
                                .font(.appCaption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        if player.isHost {
                            Image(systemName: "crown.fill")
                                .foregroundColor(AppTheme.accentSoft)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("\(room.activePlayers.count) من ٥ لاعبين")
                .font(.appCaption)
                .foregroundColor(AppTheme.textSecondary)

            if room.isHost {
                primaryButton("نبدأ", filled: true) {
                    Task { await room.start() }
                }
                .disabled(!room.canStart || room.isWorking)
                .opacity(room.canStart ? 1 : 0.5)
                if room.activePlayers.count < 2 {
                    Text("ننتظر لاعب ثاني على الأقل")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("ننتظر صاحب الغرفة يبدأ")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    private func primaryButton(
        _ title: String,
        filled: Bool,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: filled ? AppTheme.textOnAccent : AppTheme.accent))
                }
                Text(isLoading ? "لحظة…" : title)
                    .font(.appHeadline)
            }
            .foregroundColor(filled ? AppTheme.textOnAccent : AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(filled ? AppTheme.accent : AppTheme.accentSoft)
            .cornerRadius(24)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.85 : 1)
    }
}
