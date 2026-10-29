//
//  GameManager.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import Foundation
import Combine
import SwiftData

class GameManager: ObservableObject {
    @Published var players: [Player] = []
    @Published var currentChallenge: ObjectChallenge?
    @Published var currentRound: Int = 0
    @Published var timeRemaining: Int = 10
    @Published var isGameActive: Bool = false
    @Published var gameEnded: Bool = false
    @Published var leaderboard: [Player] = []
    
    private var timer: Timer?
    private let roundDuration: Int = 10
    private let multipeerService: MultipeerService
    private var profileManager: ProfileManager?
    private var roundAnswers: [String: (found: Bool, time: TimeInterval)] = [:]
    private var roundFirstFinder: String?
    private var roundEnded: Bool = false
    private let challenges: [ObjectChallenge] = [
        ObjectChallenge(objectName: "book", round: 1),
        ObjectChallenge(objectName: "glasses", round: 2),
        ObjectChallenge(objectName: "water bottle", round: 3),
        ObjectChallenge(objectName: "phone", round: 4),
        ObjectChallenge(objectName: "cup", round: 5),
        ObjectChallenge(objectName: "bag", round: 6),
        ObjectChallenge(objectName: "shoes", round: 7),
        ObjectChallenge(objectName: "pen", round: 8),
        ObjectChallenge(objectName: "watch", round: 9),
        ObjectChallenge(objectName: "keys", round: 10)
    ]

    /// أعلى نقاط ممكنة (أول من يلقى الغرض ياخذ ٢ كل جولة) — نهاية مسار السباق.
    var maxPossibleScore: Int { challenges.count * 2 }
    
    init(multipeerService: MultipeerService, profileManager: ProfileManager? = nil) {
        self.multipeerService = multipeerService
        self.profileManager = profileManager
        setupMessageHandling()
    }
    
    func setProfileManager(_ manager: ProfileManager) {
        self.profileManager = manager
    }
    
    func setupMessageHandling() {
        multipeerService.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }
    }
    
    func addPlayer(_ player: Player) {
        // Check by peerID, not id (since id is UUID and always unique)
        if !players.contains(where: { $0.peerID == player.peerID && !player.peerID.isEmpty }) {
            players.append(player)
            // Force objectWillChange to ensure UI updates
            objectWillChange.send()
            print("👤 Added player: \(player.username) (peerID: \(player.peerID)) (Total: \(players.count))")
        } else {
            // Update existing player's username or avatar if changed
            if let index = players.firstIndex(where: { $0.peerID == player.peerID }) {
                var didChange = false
                if players[index].username != player.username {
                    players[index].username = player.username
                    didChange = true
                    print("🔄 Updated player username: \(player.username) (peerID: \(player.peerID))")
                }
                if players[index].avatarImageName != player.avatarImageName {
                    players[index].avatarImageName = player.avatarImageName
                    didChange = true
                    print("🔄 Updated player avatar: \(player.avatarImageName) (peerID: \(player.peerID))")
                }
                if didChange {
                    objectWillChange.send()
                } else {
                    print("⚠️ Player already exists: \(player.username) (peerID: \(player.peerID))")
                }
            }
        }
    }
    
    func removePlayer(peerID: String) {
        players.removeAll { $0.peerID == peerID }
    }
    
    func resetForLobby() {
        timer?.invalidate()
        timer = nil
        isGameActive = false
        gameEnded = false
        currentRound = 0
        currentChallenge = nil
        timeRemaining = roundDuration
        roundAnswers = [:]
        roundFirstFinder = nil
        roundEnded = false
        leaderboard = []
        players.removeAll()
        objectWillChange.send()
    }
    
    func startGame() {
        guard multipeerService.isHost else { return }
        guard multipeerService.connectedPeers.count >= 1 else {
            print("⚠️ Cannot start: no connected guests")
            return
        }
        let expectedPlayers = multipeerService.connectedPeers.count + 1
        guard players.count >= 2 && players.count <= 5 && players.count == expectedPlayers else {
            print("⚠️ Cannot start: player count \(players.count) != connected \(expectedPlayers)")
            return
        }
        
        isGameActive = true
        currentRound = 0
        resetScores()
        
        let message = GameMessage(
            type: .gameStart,
            data: [:],
            playerID: nil,
            username: nil,
            score: nil,
            answer: nil,
            responseTime: nil
        )
        multipeerService.sendMessage(message)
    }

    func beginGameplay() {
        guard multipeerService.isHost else { return }
        guard isGameActive, currentRound == 0, currentChallenge == nil else { return }
        startRound()
    }
    
    func startRound() {
        guard currentRound < challenges.count else {
            endGame()
            return
        }
        
        currentRound += 1
        currentChallenge = challenges[currentRound - 1]
        timeRemaining = roundDuration
        roundAnswers = [:]
        roundFirstFinder = nil
        roundEnded = false
        
        if multipeerService.isHost {
            let message = GameMessage(
                type: .question,
                data: ["object": currentChallenge!.objectName, "round": "\(currentRound)"],
                playerID: nil,
                username: nil,
                score: nil,
                answer: nil,
                responseTime: nil
            )
            multipeerService.sendMessage(message)
            
            startTimer()
        }
    }
    
    func startTimer() {
        timer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timer?.invalidate()
                self.processRoundResults()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
    
    func submitObjectFound(found: Bool, confidence: Double = 1.0) -> Int? {
        guard let challenge = currentChallenge else { return nil }
        let responseTime = TimeInterval(roundDuration - timeRemaining)
        
        // Send message with found status (using answer field as boolean: 1 = found, 0 = not found)
        let message = GameMessage(
            type: .answer,
            data: ["object": challenge.objectName, "confidence": "\(confidence)"],
            playerID: multipeerService.myPeerID.displayName,
            username: multipeerService.username,
            score: nil,
            answer: found ? 1 : 0,
            responseTime: responseTime
        )
        multipeerService.sendMessage(message)
        
        // Local processing
        if found {
            roundAnswers[multipeerService.username] = (found: true, time: responseTime)
            let points = awardPoints(for: multipeerService.username)
            print("✅ Object found! Points: \(points), Time: \(responseTime)s")
            
            // Host moves all players to next round immediately when first object is found
            if multipeerService.isHost {
                endRoundEarly()
            }
            return points
        }
        return nil
    }
    
    private func awardPoints(for username: String) -> Int {
        let isFirst = roundFirstFinder == nil
        if isFirst {
            roundFirstFinder = username
        }
        
        let points = isFirst ? 2 : 1
        if let index = players.firstIndex(where: { $0.username == username }) {
            players[index].score += points
            objectWillChange.send()
        }
        return points
    }
    
    func processRoundResults() {
        guard !roundEnded else { return }
        roundEnded = true
        timer?.invalidate()
        
        // الضيوف ينتظرون سؤال الجولة الجاية من المضيف بدل ما يتقدمون لحالهم
        guard multipeerService.isHost else { return }
        
        // Brief pause so late answers can arrive, then next round
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            if self.currentRound < self.challenges.count {
                self.startRound()
            } else {
                self.endGame()
            }
        }
    }
    
    private func endRoundEarly() {
        guard !roundEnded else { return }
        roundEnded = true
        timer?.invalidate()
        
        // Short delay to let UIs show the success message then move on
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            if self.currentRound < self.challenges.count {
                self.startRound()
            } else {
                self.endGame()
            }
        }
    }
    
    func endGame() {
        isGameActive = false
        timer?.invalidate()
        
        // Sort players by score
        leaderboard = players.sorted { $0.score > $1.score }
        
        // Save scores to profiles for all players
        saveScoresToProfiles()
        
        // Send final leaderboard to all players (host sends to everyone)
        if multipeerService.isHost {
            // Wait a moment to ensure all final answers are processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                // Update leaderboard one final time
                self.leaderboard = self.players.sorted { $0.score > $1.score }
                
                // Send to all connected players
                let leaderboardData = self.leaderboard.map { "\($0.username):\($0.score)" }.joined(separator: ",")
                let endMessage = GameMessage(
                    type: .gameEnd,
                    data: ["leaderboard": leaderboardData],
                    playerID: nil,
                    username: nil,
                    score: nil,
                    answer: nil,
                    responseTime: nil
                )
                self.multipeerService.sendMessage(endMessage)
                
                // Host also sets gameEnded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.gameEnded = true
                }
            }
        } else {
            // Non-host players wait for gameEnd message
            // gameEnded will be set in handleMessage
        }
    }
    
    func saveScoresToProfiles() {
        guard let profileManager = profileManager else { return }
        
        // Determine winner (highest score)
        let winner = leaderboard.first
        
        // Save scores for all players
        for player in players {
            let won = winner?.username == player.username
            profileManager.updateProfile(
                username: player.username,
                gameScore: player.score,
                won: won
            )
        }
    }
    
    func handleMessage(_ message: GameMessage) {
        switch message.type {
        case .playerJoined:
            // When a player joins, add them with their username
            if let peerID = message.playerID, let username = message.username {
                let avatarImageName = PlayerAvatars.imageName(for: message.data["avatar"])
                print("📨 Received playerJoined: \(username) (peerID: \(peerID))")
                print("   Current players before: \(players.count)")
                print("   Current player list: \(players.map { "\($0.username):\($0.peerID)" }.joined(separator: ", "))")
                print("   My username: \(multipeerService.username), My peerID: \(multipeerService.myPeerID.displayName)")
                
                // Skip if this is our own message (we already added ourselves)
                if peerID == multipeerService.myPeerID.displayName {
                    print("   ⏭️ Skipping own playerJoined message")
                    // But make sure we're in the list
                    if !players.contains(where: { $0.peerID == peerID }) {
                        let player = Player(
                            username: username,
                            isHost: multipeerService.isHost,
                            peerID: peerID,
                            avatarImageName: avatarImageName
                        )
                        addPlayer(player)
                        print("✅ Added self from message: \(username) (\(peerID))")
                    }
                    return
                }
                
                // Check if player already exists by peerID
                if let existingIndex = players.firstIndex(where: { $0.peerID == peerID }) {
                    var didChange = false
                    if players[existingIndex].username != username {
                        players[existingIndex].username = username
                        didChange = true
                        print("✅ Updated player username: \(username) for peerID: \(peerID)")
                    }
                    if players[existingIndex].avatarImageName != avatarImageName {
                        players[existingIndex].avatarImageName = avatarImageName
                        didChange = true
                        print("✅ Updated player avatar: \(avatarImageName) for peerID: \(peerID)")
                    }
                    if didChange {
                        objectWillChange.send()
                    } else {
                        print("ℹ️ Player already exists with same username: \(username) (peerID: \(peerID))")
                    }
                } else {
                    // Add new player - this is important!
                    let player = Player(
                        username: username,
                        isHost: false,
                        peerID: peerID,
                        avatarImageName: avatarImageName
                    )
                    addPlayer(player)
                    print("✅ Added NEW player from message: \(username) (\(peerID))")
                    print("   New total: \(players.count) players")
                    print("   Updated player list: \(players.map { "\($0.username):\($0.peerID)" }.joined(separator: ", "))")
                }
            } else {
                print("⚠️ playerJoined message missing peerID or username")
                print("   playerID: \(message.playerID ?? "nil"), username: \(message.username ?? "nil")")
            }
            
        case .gameStart:
            isGameActive = true
            currentRound = 0
            resetScores()
            objectWillChange.send()
            
        case .question:
            if let objectName = message.data["object"],
               let roundStr = message.data["round"],
               let round = Int(roundStr) {
                currentRound = round
                // Find matching challenge
                if let challenge = challenges.first(where: { $0.objectName == objectName && $0.round == round }) {
                    currentChallenge = challenge
                    timeRemaining = roundDuration
                    // بدون هذا الضيف يحسب أول لاقي من الجولة اللي قبل ويعطي ١ بدل ٢
                    roundAnswers = [:]
                    roundFirstFinder = nil
                    roundEnded = false
                    if !multipeerService.isHost {
                        startTimer()
                    }
                    print("🎯 Round \(round): Find \(objectName)")
                }
            }
            
        case .answer:
            if let username = message.username,
               let found = message.answer, // 1 = found, 0 = not found
               let responseTime = message.responseTime,
               let challenge = currentChallenge {
                // نفس اللاعب ما ياخذ نقاط مرتين في نفس الجولة
                if roundAnswers[username]?.found == true { break }
                // Store result for processing
                roundAnswers[username] = (found: found == 1, time: responseTime)
                
                // Process result immediately if object was found
                if found == 1 {
                    // Skip double-award for the sender (they already scored locally)
                    if username != multipeerService.username {
                        let points = awardPoints(for: username)
                        print("✅ \(username) found \(challenge.objectName)! Points: \(points)")
                    }
                    
                    // Host advances everyone as soon as the first correct find happens
                    if multipeerService.isHost {
                        endRoundEarly()
                    }
                }
                
                // If host, also update leaderboard for all players
                if multipeerService.isHost {
                    // Broadcast updated scores
                    let leaderboardData = players.map { "\($0.username):\($0.score)" }.joined(separator: ",")
                    let updateMessage = GameMessage(
                        type: .leaderboard,
                        data: ["leaderboard": leaderboardData],
                        playerID: nil,
                        username: nil,
                        score: nil,
                        answer: nil,
                        responseTime: nil
                    )
                    multipeerService.sendMessage(updateMessage)
                }
            }
            
        case .gameEnd:
            isGameActive = false
            timer?.invalidate()
            
            // Update leaderboard from message data
            if let leaderboardStr = message.data["leaderboard"] {
                let entries = leaderboardStr.split(separator: ",")
                for entry in entries {
                    let parts = entry.split(separator: ":")
                    if parts.count == 2,
                       let score = Int(parts[1]) {
                        let username = String(parts[0])
                        // Update existing player or create if missing
                        if let index = players.firstIndex(where: { $0.username == username }) {
                            players[index].score = score
                        } else {
                            // Add player if not in list
                            let player = Player(username: username, score: score, isHost: false, peerID: "")
                            players.append(player)
                        }
                    }
                }
            }
            
            // Always sort and update leaderboard
            leaderboard = players.sorted { $0.score > $1.score }
            
            // Save scores to profiles for all players (including non-host)
            saveScoresToProfiles()
            
            // Set gameEnded after processing - ensure all players see it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.gameEnded = true
                // Force update leaderboard one more time
                self.leaderboard = self.players.sorted { $0.score > $1.score }
            }
            
        case .leaderboard:
            if let leaderboardStr = message.data["leaderboard"] {
                let entries = leaderboardStr.split(separator: ",")
                for entry in entries {
                    let parts = entry.split(separator: ":")
                    if parts.count == 2,
                       let score = Int(parts[1]),
                       let index = players.firstIndex(where: { $0.username == String(parts[0]) }) {
                        players[index].score = score
                    }
                }
                leaderboard = players.sorted { $0.score > $1.score }
            }
            
        default:
            break
        }
    }
    
    func resetScores() {
        for i in 0..<players.count {
            players[i].score = 0
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

