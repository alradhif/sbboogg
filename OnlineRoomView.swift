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
    // Never started: GameView and LeaderboardView expect one, and it carries our name.
    @StateObject private var multipeerService: MultipeerService
    @StateObject private var gameManager: GameManager
    @State private var codeInput = ""
    @State private var showGame = false
    @State private var roomTapLocked = false
    @State private var pendingRoomAction: PendingRoomAction?

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

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 24)

                Group {
                    switch auth.state {
                    case .loading:
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("جاري الاتصال…")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .signedOut:
                        ScrollView {
                            SignInOptionsView()
                                .padding(.horizontal, 28)
                                .padding(.vertical, 16)
                        }
                    case .guest, .facebook:
                        if room.roomID == nil {
                            createOrJoin
                                .padding(.horizontal, 28)
                        } else {
                            ScrollView {
                                lobby
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                }

                if let message = room.errorMessage {
                    Text(message)
                        .font(.appCaption)
                        .foregroundColor(AppTheme.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            room.gameManager = gameManager
            gameManager.onlineRoom = room
            profileManager.setModelContext(modelContext)
            gameManager.setProfileManager(profileManager)
            multipeerService.username = username
            multipeerService.avatarImageName = PlayerAvatars.imageName(for: avatarImageName)
            Task {
                if auth.state == .signedOut {
                    await auth.signInAsGuest()
                }
            }
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
        .environment(\.layoutDirection, .leftToRight)
    }

    private var createOrJoin: some View {
        VStack(spacing: 18) {
            Image("camel")
                .resizable()
                .scaledToFit()
                .frame(height: 120)

            primaryButton(
                "سوّ غرفة وادعِ ربعك",
                filled: true,
                isLoading: pendingRoomAction == .create && room.isWorking
            ) {
                guard !roomTapLocked, !room.isWorking else { return }
                roomTapLocked = true
                pendingRoomAction = .create
                Task {
                    await room.create(username: username, avatarImageName: avatarImageName)
                    pendingRoomAction = nil
                    roomTapLocked = false
                }
            }

            Text("أو ادخل بكود صاحبك")
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)

            TextField("", text: codeBinding, prompt: Text("الكود").foregroundStyle(AppTheme.textSecondary))
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.accent)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            primaryButton(
                "ادخل",
                filled: false,
                isLoading: pendingRoomAction == .join && room.isWorking
            ) {
                guard !roomTapLocked, !room.isWorking else { return }
                roomTapLocked = true
                pendingRoomAction = .join
                Task {
                    await room.join(code: codeInput, username: username, avatarImageName: avatarImageName)
                    pendingRoomAction = nil
                    roomTapLocked = false
                }
            }
            .disabled(codeInput.count < 5 || room.isWorking || roomTapLocked)
            .opacity(codeInput.count < 5 ? 0.5 : 1)
        }
        .disabled(auth.isWorking || auth.state == .loading)
    }

    private var codeBinding: Binding<String> {
        Binding(
            get: { codeInput },
            set: { newValue in
                let cleaned = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(5))
                if cleaned != codeInput {
                    codeInput = cleaned
                }
            }
        )
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
        .disabled(isLoading || roomTapLocked)
        .opacity(isLoading ? 0.85 : 1)
    }
}
