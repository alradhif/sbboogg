//
//  UsernameEntryView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import MultipeerConnectivity
import SwiftData

struct UsernameEntryView: View {
    @Binding var username: String
    @Binding var showLobby: Bool
    @Binding var isHost: Bool
    @ObservedObject var multipeerService: MultipeerService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var profileManager = ProfileManager()
    @State private var availableHosts: [MCPeerID] = []
    @State private var isSearching: Bool = false
    @State private var showProfile: Bool = false
    @State private var showSettings: Bool = false
    @State private var showLeaderboard: Bool = false
    @State private var showInvitations: Bool = false
    @State private var showJoinHint: Bool = false
    @State private var showInviteHint: Bool = false
    @State private var usernameFromProfile: Bool = false
    @State private var selectedPlayMode: PlayMode = .online
    @State private var showNearbyPicker: Bool = false
    @State private var navigateToOnline: Bool = false
    
    private var profileAvatarName: String {
        PlayerAvatars.imageName(for: profileManager.currentProfile?.avatarImageName)
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            // Hidden navigation trigger to lobby when showLobby becomes true
            NavigationLink(
                destination: LobbyView(multipeerService: multipeerService, isHost: isHost, showLobby: $showLobby),
                isActive: $showLobby
            ) {
                EmptyView()
            }
            .opacity(0)
            .accessibilityHidden(true)

            GeometryReader { geo in
                Image("stig")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 1.1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(x: -12, y: 230)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 24) {
                        Image("camel")
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(geo.size.height * 0.25, 240))

                        VStack(spacing: 10) {
                            if usernameFromProfile {
                                Text(username)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 40)
                                    .background(AppTheme.surface)
                                    .cornerRadius(38)
                            } else {
                                TextField("أسم السبوق", text: $username)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .cornerRadius(38)
                                    .padding(.horizontal, 40)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)

                                if username.isEmpty {
                                    Text("الرجاء إدخال اسم المستخدم")
                                        .foregroundColor(AppTheme.error)
                                        .font(.appCaption)
                                }
                            }
                        }

                        PlayModeCarouselView(
                            selection: $selectedPlayMode,
                            isInteractionEnabled: !username.isEmpty,
                            onModeActivated: handleModeActivated
                        )
                        .padding(.top, 4)
                        .opacity(username.isEmpty ? 0.45 : 1)

                        if isSearching {
                            ProgressView("Searching for games...")
                                .padding(.top, 16)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 8)
                    .frame(minHeight: geo.size.height)
                }
            }
            
            if showJoinHint {
                JoinHintView(
                    onContinue: {
                        showJoinHint = false
                        startAsGuest()
                    },
                    onDismiss: {
                        showJoinHint = false
                    }
                )
                .zIndex(100)
                .transition(.opacity)
            }
            
            if showInviteHint {
                InviteHintView(
                    onContinue: {
                        showInviteHint = false
                        startAsHost()
                    },
                    onDismiss: {
                        showInviteHint = false
                    }
                )
                .zIndex(100)
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            UsernameEntryBottomBar(
                profileAvatarName: profileAvatarName,
                showsProfileAvatar: usernameFromProfile,
                onProfile: { showProfile = true },
                onSettings: { showSettings = true },
                onLeaderboard: { showLeaderboard = true },
                onInvitations: { showInvitations = true }
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showProfile) {
            ProfileView(
                profileManager: profileManager,
                onLogout: {
                    profileManager.clearCurrentProfile()
                    username = ""
                    usernameFromProfile = false
                    showLobby = false
                    isHost = false
                    showProfile = false
                }
            )
            .environment(\.layoutDirection, .leftToRight)
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsSheetView(profileManager: profileManager)
        }
        .sheet(isPresented: $showLeaderboard) {
            NavigationView {
                AllPlayersLeaderboardView(profileManager: profileManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("تم") {
                                showLeaderboard = false
                            }
                            .foregroundStyle(AppTheme.accent)
                            .fontWeight(.semibold)
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .sheet(isPresented: $showInvitations) {
            InvitationsView(multipeerService: multipeerService) {
                showInvitations = false
            }
        }
        .onAppear {
            profileManager.setModelContext(modelContext)
            if let profile = profileManager.currentProfile {
                username = profile.username
                usernameFromProfile = true
            }
        }
        .onChange(of: showProfile) { oldValue, newValue in
            if oldValue == true && newValue == false {
                if let profile = profileManager.currentProfile {
                    username = profile.username
                    usernameFromProfile = true
                } else {
                    username = ""
                    usernameFromProfile = false
                    showLobby = false
                    isHost = false
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToOnline) {
            OnlineRoomView(
                username: username.trimmingCharacters(in: .whitespaces),
                avatarImageName: profileAvatarName
            )
        }
        .sheet(isPresented: $showNearbyPicker) {
            NearbyPlayPickerView(
                onHost: {
                    showNearbyPicker = false
                    showInviteHint = true
                },
                onJoin: {
                    showNearbyPicker = false
                    showJoinHint = true
                },
                onDismiss: { showNearbyPicker = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func handleModeActivated(_ mode: PlayMode) {
        guard !username.isEmpty else { return }
        switch mode {
        case .nearby:
            showNearbyPicker = true
        case .online:
            navigateToOnline = true
        case .random:
            break
        }
    }

    func startAsHost() {
        guard !username.isEmpty else { return }
        let profile = profileManager.getOrCreateLocalProfile(username: username.trimmingCharacters(in: .whitespaces))
        isHost = true
        multipeerService.startHosting(
            username: username.trimmingCharacters(in: .whitespaces),
            avatarImageName: profile.avatarImageName
        )
        showLobby = true
    }
    
    func startAsGuest() {
        guard !username.isEmpty else { return }
        let profile = profileManager.getOrCreateLocalProfile(username: username.trimmingCharacters(in: .whitespaces))
        isHost = false
        isSearching = true
        multipeerService.startBrowsing(
            username: username.trimmingCharacters(in: .whitespaces),
            avatarImageName: profile.avatarImageName
        )
        
        // Wait a bit for discovery, then show lobby
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            showLobby = true
        }
    }
}

// MARK: - Join Hint (التعليمات - الإجتماع)
struct JoinHintView: View {
    var onContinue: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 0) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .zIndex(1)
                    .offset(y: 8)
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("التعليمات")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text("1")
                        .font(.appTitle(28))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("الإجتماع")
                        .font(.appTitle(22))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Rectangle()
                        .fill(AppTheme.textSecondary.opacity(0.3))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                    
                    Text("حدد الميدان، خش مع مجموعة\nأو اعزم ربعك، وخلوكم جنب بعض\nعشان يتفعّل البلوتوث")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 12) {
                        Button(action: onDismiss) {
                            Text("إلغاء")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Button(action: onContinue) {
                            Text("استمر")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(24)
                .frame(maxWidth: 320)
                .background(AppTheme.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.textPrimary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .offset(y: -20)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Invite Hint (التعليمات - الدعوات)
struct InviteHintView: View {
    var onContinue: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 0) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .zIndex(1)
                    .offset(y: 8)
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("التعليمات")
                        .font(.appCaption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text("الدعوات")
                        .font(.appTitle(22))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Rectangle()
                        .fill(AppTheme.textSecondary.opacity(0.3))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                    
                    Text("انتظر قبول الدعوات التي أرسلتها وبعدها ننطلق.")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 12) {
                        Button(action: onDismiss) {
                            Text("إلغاء")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Button(action: onContinue) {
                            Text("استمر")
                                .font(.appHeadline)
                                .foregroundColor(AppTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(24)
                .frame(maxWidth: 320)
                .background(AppTheme.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.textPrimary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .offset(y: -20)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - قريب مني: اعزم أو اقلط

struct NearbyPlayPickerView: View {
    var onHost: () -> Void
    var onJoin: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            VStack(spacing: 18) {
                Text("قريب مني")
                    .font(.appTitle(26))
                    .foregroundColor(AppTheme.accent)

                Text("اختاري كيف تبغى تلعبين مع اللي حولك")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)

                VStack(spacing: 14) {
                    Button(action: onHost) {
                        Text("اعزمهم على مجموعتك")
                            .font(.appHeadline)
                            .foregroundColor(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    Button(action: onJoin) {
                        Text("اقلط بمجموعة")
                            .font(.appHeadline)
                            .foregroundColor(AppTheme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding(.top, 4)

                Button("إلغاء", action: onDismiss)
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// MARK: - Bottom toolbar

private struct UsernameEntryBottomBar: View {
    let profileAvatarName: String
    let showsProfileAvatar: Bool
    var onProfile: () -> Void
    var onSettings: () -> Void
    var onLeaderboard: () -> Void
    var onInvitations: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            bottomItem(title: "البروفايل", action: onProfile) {
                if showsProfileAvatar {
                    Image(profileAvatarName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.accent.opacity(0.35), lineWidth: 1.5))
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22, weight: .medium))
                }
            }

            bottomItem(title: "الإعدادات", systemImage: "gearshape.fill", action: onSettings)
            bottomItem(title: "التصنيف", systemImage: "trophy.fill", action: onLeaderboard)
            bottomItem(title: "دعوات", systemImage: "envelope.fill", action: onInvitations)
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            AppTheme.surface
                .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider()
                .background(AppTheme.textSecondary.opacity(0.2))
        }
    }

    private func bottomItem(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        bottomItem(title: title, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
        }
    }

    private func bottomItem(
        title: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> some View
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon()
                    .foregroundStyle(AppTheme.accent)
                    .frame(height: 28)

                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Play mode cards (Ludo-style carousel)

enum PlayMode: String, CaseIterable, Identifiable {
    case nearby
    case online
    case random

    var id: String { rawValue }

    var cardColor: Color {
        switch self {
        case .nearby: return Color(hex: "F5C518")
        case .online: return Color(hex: "D32F2F")
        case .random: return Color(hex: "43A047")
        }
    }

    var iconSystemName: String {
        switch self {
        case .nearby: return "bluetooth"
        case .online: return "globe"
        case .random: return "person.2.fill"
        }
    }

    var title: String {
        switch self {
        case .nearby: return "قريب مني"
        case .online: return "أونلاين"
        case .random: return "لعب عشوائي"
        }
    }

    var subtitle: String {
        switch self {
        case .nearby: return "بلوتوث مع اللي حولك"
        case .online: return "العب مع ربعك البعيدين"
        case .random: return "قريباً"
        }
    }

    var isPlayable: Bool { self != .random }

    /// ترتيب العرض: أخضر يسار — أحمر وسط — أصفر يمين (مثل التصميم).
    static let carouselOrder: [PlayMode] = [.random, .online, .nearby]
}

struct PlayModeCarouselView: View {
    @Binding var selection: PlayMode
    var isInteractionEnabled: Bool = true
    var onModeActivated: (PlayMode) -> Void = { _ in }

    @State private var dragOffset: CGFloat = 0

    private let modes = PlayMode.carouselOrder
    private let cardWidth: CGFloat = 178
    private let cardHeight: CGFloat = 212
    /// تداخل بسيط مثل لودو — يبان الكرتان الجانبيان خلف الوسط.
    private let cardSpacing: CGFloat = -34
    /// إزاحة أفقية للكروت (موجب = يمين).
    private let carouselBiasX: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 320)

            HStack(spacing: cardSpacing) {
                ForEach(modes) { mode in
                    let isSelected = selection == mode
                    let distance = abs(modeIndex(mode) - modeIndex(selection))
                    PlayModeCardView(mode: mode, isSelected: isSelected)
                        .frame(width: cardWidth, height: cardHeight)
                        .scaleEffect(isSelected ? 1.06 : 0.78)
                        .opacity(isSelected ? 1 : 0.92)
                        .rotation3DEffect(
                            .degrees(cardYaw(for: mode)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .center,
                            perspective: 0.34
                        )
                        .offset(y: isSelected ? 0 : 10)
                        .zIndex(isSelected ? 10 : Double(3 - distance))
                        .onTapGesture {
                            snapTo(mode, activate: true)
                        }
                }
            }
            .frame(height: cardHeight + 20, alignment: .center)
            .offset(x: centeredOffset(containerWidth: width) + carouselBiasX + dragOffset)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { dragOffset = $0.translation.width }
                    .onEnded { value in
                        let total = value.translation.width + value.predictedEndTranslation.width * 0.12
                        var index = modeIndex(selection)
                        if total < -35 {
                            index = min(index + 1, modes.count - 1)
                        } else if total > 35 {
                            index = max(index - 1, 0)
                        }
                        snapTo(modes[index], activate: false)
                    }
            )
            .frame(width: width, height: cardHeight + 28)
        }
        .frame(height: cardHeight + 28)
        .padding(.horizontal, 4)
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            selection = .online
            dragOffset = 0
        }
    }

    private func modeIndex(_ mode: PlayMode) -> Int {
        modes.firstIndex(of: mode) ?? 1
    }

    /// Cover flow: الوسط مستوي، الجانب يدور للخارج.
    private func cardYaw(for mode: PlayMode) -> Double {
        let idx = modeIndex(mode)
        let center = modeIndex(selection)
        if idx == center { return 0 }
        if idx < center { return 38 }
        return -38
    }

    private func centeredOffset(containerWidth: CGFloat) -> CGFloat {
        let index = modeIndex(selection)
        let selectedCenter = CGFloat(index) * (cardWidth + cardSpacing) + cardWidth / 2
        return containerWidth / 2 - selectedCenter
    }

    private func snapTo(_ mode: PlayMode, activate: Bool) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selection = mode
            dragOffset = 0
        }
        guard activate, isInteractionEnabled, mode.isPlayable else { return }
        onModeActivated(mode)
    }
}

/// شعار البلوتوث الكلاسيكي (نفس شكل أيقونة Material / الصورة المرجعية) — 24×24.
private struct BluetoothLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24
        let sy = rect.height / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: point(17.71, 7.71))
        path.addLine(to: point(12, 2))
        path.addLine(to: point(11, 2))
        path.addLine(to: point(11, 9.59))
        path.addLine(to: point(6.41, 5))
        path.addLine(to: point(5, 6.41))
        path.addLine(to: point(10.59, 12))
        path.addLine(to: point(5, 17.59))
        path.addLine(to: point(6.41, 19))
        path.addLine(to: point(11, 14.41))
        path.addLine(to: point(11, 22))
        path.addLine(to: point(12, 22))
        path.addLine(to: point(17.71, 16.29))
        path.addLine(to: point(13.13, 11.7))
        path.addLine(to: point(17.71, 7.11))
        path.closeSubpath()
        return path
    }
}

private struct PlayModeCardView: View {
    let mode: PlayMode
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(mode.cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white, lineWidth: 6)
                )
                .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 12 : 6, y: 5)

            VStack(spacing: 0) {
                Spacer(minLength: 8)
                modeIcon
                    .padding(.bottom, 8)
                Spacer()
                VStack(spacing: 6) {
                    Text(mode.title)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 4)
                    Text(mode.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .padding(.bottom, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
                .padding(.top, 2)
            }

            if !mode.isPlayable {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                Text("قريباً")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .offset(y: -36)
            }
        }
        .opacity(mode.isPlayable ? 1 : 0.88)
    }

    @ViewBuilder
    private var modeIcon: some View {
        if mode == .nearby {
            BluetoothLogoShape()
                .fill(Color.white)
                .frame(width: 48, height: 48)
        } else {
            Image(systemName: mode.iconSystemName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

#Preview {
    NavigationStack {
        UsernameEntryView(
            username: .constant("Test"),
            showLobby: .constant(false),
            isHost: .constant(false),
            multipeerService: MultipeerService()
        )
    }
}
