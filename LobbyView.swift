//
//  LobbyView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//



import SwiftUI
import MultipeerConnectivity
import SwiftData


struct LobbyView: View {
    @ObservedObject var multipeerService: MultipeerService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameManager: GameManager
    @StateObject private var profileManager = ProfileManager()
    @State private var showGame: Bool = false
    @State private var showLeaderboard: Bool = false
    @State private var showInvitations: Bool = false
    @State private var playerCount: Int = 0
    let isHost: Bool
    
    init(multipeerService: MultipeerService, isHost: Bool) {
        self.multipeerService = multipeerService
        self.isHost = isHost
        _gameManager = StateObject(wrappedValue: GameManager(multipeerService: multipeerService))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppTheme.background
                    .ignoresSafeArea()

                
                GeometryReader { geo in
                    Image("stig")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.77) // زيادة بنسبة 10%
                        .padding(.bottom, 0)
                        .offset(x: -12, y: geo.size.height * 0.60)
                
                    
                
                    VStack(spacing: 0) {
                        // Header Section
                        headerSection
                            .padding(.top, 60)
                        
                        Spacer()
                            .frame(height: 30)
                        
                        // Wait text
                        Text("انتظر انضمام الجميع :")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // Players list card
                        playersListCard
                            .padding(.horizontal, 20)
                        
                        // Available players section (only for host)
                        if isHost {
                            Spacer()
                                .frame(height: 20)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("لاعبون متاحون")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, 20)
                                
                                if filteredAvailablePeers.isEmpty {
                                    Text("جاري البحث عن لاعبين...")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(filteredAvailablePeers) { availablePeer in
                                                inviteButton(for: availablePeer)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Start button (only for host)
                        if isHost {
                            startGameButton
                                .padding(.horizontal, 20)
                                .padding(.bottom, 30)
                        } else {
                            guestWaitingView
                                .padding(.bottom, 30)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            profileManager.setModelContext(modelContext)
            gameManager.setProfileManager(profileManager)
            gameManager.setupMessageHandling()
            setupLobby()
            playerCount = gameManager.players.count
            BackgroundMusicManager.shared.startBackgroundMusic()
        }
        .onChange(of: multipeerService.connectedPeers) { peers in
            print("🔄 Connected peers changed: \(peers.count) peers")
            print("   Connected peer names: \(peers.map { $0.displayName }.joined(separator: ", "))")
            updatePlayers(peers: peers)
            print("📊 Total players after update: \(gameManager.players.count)")
            
            // Send our playerJoined message to all newly connected peers
            if !peers.isEmpty && !multipeerService.username.isEmpty {
                multipeerService.sendMessage(multipeerService.makePlayerJoinedMessage())
                print("📤 Sent playerJoined message to \(peers.count) connected peers")
            }
        }
        .onChange(of: gameManager.players.count) { count in
            print("📊 Player count changed: \(count)")
            playerCount = count
        }
        .onReceive(gameManager.$players) { players in
            playerCount = players.count
            print("📊 Received players update: \(players.count) players")
        }
        .onChange(of: multipeerService.availablePeers) { peers in
            print("🔄 UI: Available peers changed, count: \(peers.count)")
            for peer in peers {
                print("   - \(peer.username) (\(peer.peerID.displayName))")
            }
        }
        .onChange(of: gameManager.isGameActive) { active in
            if active {
                showInvitations = false
                BackgroundMusicManager.shared.startBackgroundMusic()
                showGame = true
            }
        }
        .onChange(of: gameManager.gameEnded) { ended in
            if ended {
                showLeaderboard = true
            }
        }
        .fullScreenCover(isPresented: $showGame) {
            GameView(gameManager: gameManager, multipeerService: multipeerService)
        }
        .fullScreenCover(isPresented: $showLeaderboard) {
            LeaderboardView(gameManager: gameManager, multipeerService: multipeerService)
        }
        .onChange(of: multipeerService.pendingInvitations.count) { count in
            if count > 0 && !isHost {
                showInvitations = true
            } else {
                showInvitations = false
            }
        }
        .onChange(of: multipeerService.isConnected) { connected in
            if connected && !isHost {
                showInvitations = false
            }
        }
        .fullScreenCover(isPresented: $showInvitations) {
            InvitationsView(multipeerService: multipeerService) {
                showInvitations = false
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Back button
//            Button(action: {
//                dismiss()
//            }) {
//                Image(systemName: "chevron.left")
//                    .font(.system(size: 20, weight: .semibold))
//                    .foregroundColor(.black)
//            }
            
            Spacer()
            
            // Title
            Text("الميدان")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            // Camel icon
            Image(multipeerService.avatarImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        }
        .padding(.horizontal, 20)
    }
    
    private var playersListCard: some View {
        VStack(spacing: 12) {
            // All players (including host)
            ForEach(gameManager.players, id: \.id) { player in
                HStack(spacing: 12) {
                    Image(player.avatarImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    
                    // Player name
                    Text(player.username)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .cornerRadius(16)
    }
    
    private var startGameButton: some View {
        Button(action: {
            print("🎮 Start Game button clicked!")
            startGame()
        }) {
            Text("نبدأ")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.textOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(startGameButtonColor)
                .cornerRadius(16)
        }
        .disabled(!canStartGame)
    }
    
    private var canStartGame: Bool {
        let connectedGuestCount = multipeerService.connectedPeers.count
        let lobbyCount = playerCount > 0 ? playerCount : gameManager.players.count
        let canStart = isHost
            && connectedGuestCount >= 1
            && lobbyCount >= 2
            && lobbyCount <= 5
            && lobbyCount == connectedGuestCount + 1
        print("🎮 Can start game? connectedGuests: \(connectedGuestCount), lobby: \(lobbyCount), canStart: \(canStart)")
        return canStart
    }
    
    private var startGameButtonColor: Color {
        canStartGame ? AppTheme.accent : Color.gray
    }
    
    private var filteredAvailablePeers: [MultipeerService.AvailablePeer] {
        let connectedPeerIDs = Set(multipeerService.connectedPeers.map { $0.displayName })
        return multipeerService.availablePeers.filter { availablePeer in
            !connectedPeerIDs.contains(availablePeer.peerID.displayName)
        }
    }
    
    private func inviteButton(for availablePeer: MultipeerService.AvailablePeer) -> some View {
        Button(action: {
            print("📤 Inviting: \(availablePeer.username)")
            multipeerService.sendInvite(to: availablePeer.peerID)
        }) {
            HStack(spacing: 8) {
                Image(availablePeer.avatarImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                
                Text(availablePeer.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(AppTheme.accent)
                    .font(.system(size: 18))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.surface)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }
    
    private var guestWaitingView: some View {
        VStack(spacing: 10) {
            Text("انتظر حتى يبدأ المضيف اللعبة...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            
            if !multipeerService.isConnected {
                Text("انتظر دعوة من المضيف...")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.warning)
            }
            
            if !multipeerService.pendingInvitations.isEmpty {
                Button(action: { showInvitations = true }) {
                    HStack(spacing: 8) {
                        Text("الدعوات")
                            .font(.appHeadline)
                        Text("(\(multipeerService.pendingInvitations.count))")
                            .font(.appCaption)
                    }
                    .foregroundColor(AppTheme.textOnAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.top, 8)
            }
        }
    }
    
    func setupLobby() {
        gameManager.resetForLobby()
        
        // Add current player
        let currentPlayer = Player(
            username: multipeerService.username,
            isHost: isHost,
            peerID: multipeerService.myPeerID.displayName,
            avatarImageName: multipeerService.avatarImageName
        )
        print("🏠 Setting up lobby - adding current player: \(multipeerService.username) (peerID: \(multipeerService.myPeerID.displayName))")
        gameManager.addPlayer(currentPlayer)
        playerCount = gameManager.players.count
        print("🏠 Lobby setup complete - total players: \(gameManager.players.count), state: \(playerCount)")
        
        updatePlayers(peers: multipeerService.connectedPeers)
        
        // Send playerJoined message to all connected peers (if any)
        if !multipeerService.connectedPeers.isEmpty {
            multipeerService.sendMessage(multipeerService.makePlayerJoinedMessage())
            print("📤 Sent initial playerJoined message to \(multipeerService.connectedPeers.count) peers")
        }
    }
    
    func updatePlayers(peers: [MCPeerID]) {
        print("🔄 updatePlayers called with \(peers.count) peers")
        print("   My peerID: \(multipeerService.myPeerID.displayName)")


print("   Current players in gameManager: \(gameManager.players.count)")
        print("   Current player peerIDs: \(gameManager.players.map { $0.peerID }.joined(separator: ", "))")
        print("   Connected peer displayNames: \(peers.map { $0.displayName }.joined(separator: ", "))")
        
        // Update player list based on connected peers
        // Note: Usernames are now received via playerJoined messages, so we only add placeholder if needed
        for peer in peers {
            let peerDisplayName = peer.displayName
            
            // Skip self - compare MCPeerID objects, not displayName strings (devices can have same name)
            if peer == multipeerService.myPeerID {
                print("   ⏭️ Skipping self (MCPeerID match): \(peerDisplayName)")
                continue
            }
            
            // Check if already in player list by peerID
            // Use a unique identifier - combine displayName with a hash or use the actual peer object
            // For now, we'll rely on playerJoined messages to add players with correct usernames
            // This function just ensures placeholders exist
            if gameManager.players.contains(where: { $0.peerID == peerDisplayName }) {
                print("   ⏭️ Skipping \(peerDisplayName) - already in list")
                continue
            }
            
            // Try to get username from availablePeers (where we stored it from discovery info)
            let username: String
            let avatarImageName: String
            if let availablePeer = multipeerService.availablePeers.first(where: { $0.peerID == peer }) {
                username = availablePeer.username
                avatarImageName = availablePeer.avatarImageName
                print("   📝 Found username from availablePeers: \(username)")
            } else {
                // Fallback to peer display name if not found (will be updated when playerJoined message arrives)
                username = peerDisplayName
                avatarImageName = PlayerAvatars.defaultName
                print("   ⚠️ Username not found, using displayName: \(username)")
            }
            
            let player = Player(
                username: username,
                isHost: false,
                peerID: peerDisplayName,
                avatarImageName: avatarImageName
            )
            gameManager.addPlayer(player)
            print("✅ Added player to lobby (placeholder): \(username) (\(peerDisplayName))")
        }
        
        // Remove disconnected players (but keep self)
        let connectedPeerDisplayNames = Set(peers.map { $0.displayName })
        let myPeerDisplayName = multipeerService.myPeerID.displayName
        let beforeRemove = gameManager.players.count
        gameManager.players.removeAll { player in
            let shouldRemove = !connectedPeerDisplayNames.contains(player.peerID) && player.peerID != myPeerDisplayName
            if shouldRemove {
                print("🗑️ Removing disconnected player: \(player.username) (\(player.peerID))")
            }
            return shouldRemove
        }
        let afterRemove = gameManager.players.count
        if beforeRemove != afterRemove {
            print("🗑️ Removed \(beforeRemove - afterRemove) disconnected players")
            gameManager.objectWillChange.send()
        }
        
        print("📊 Final player count: \(gameManager.players.count)")
        print("   Final players: \(gameManager.players.map { "\($0.username):\($0.peerID)" }.joined(separator: ", "))")
    }
    
    func startGame() {
        gameManager.startGame()
    }
}

#Preview {
    LobbyView(
        multipeerService: MultipeerService(),
        isHost: true
    )
}

