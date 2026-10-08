//
//  Models.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import Foundation
import SwiftData

@Model
final class Player: Identifiable {
    var id: UUID
    var username: String
    var score: Int
    var isHost: Bool
    var peerID: String
    var avatarImageName: String = PlayerAvatars.defaultName
    
    init(
        id: UUID = UUID(),
        username: String,
        score: Int = 0,
        isHost: Bool = false,
        peerID: String = "",
        avatarImageName: String = PlayerAvatars.defaultName
    ) {
        self.id = id
        self.username = username
        self.score = score
        self.isHost = isHost
        self.peerID = peerID
        self.avatarImageName = PlayerAvatars.imageName(for: avatarImageName)
    }
}

@Model
final class GameSession {
    var id: UUID
    var players: [Player]
    var currentRound: Int
    var totalRounds: Int
    var isGameActive: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), players: [Player] = [], currentRound: Int = 0, totalRounds: Int = 3, isGameActive: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.players = players
        self.currentRound = currentRound
        self.totalRounds = totalRounds
        self.isGameActive = isGameActive
        self.createdAt = createdAt
    }
}

@Model
final class PlayerProfile: Identifiable {
    var id: UUID
    var username: String
    var totalGamesPlayed: Int
    var totalScore: Int
    var bestScore: Int
    var averageScore: Double
    var gamesWon: Int
    var createdAt: Date
    var lastPlayed: Date
    var avatarImageName: String = PlayerAvatars.defaultName
    /// true for the profile that belongs to whoever uses this device.
    /// Other players' rows only feed the on-device ranking.
    var isLocalPlayer: Bool = false
    
    init(
        id: UUID = UUID(),
        username: String,
        totalGamesPlayed: Int = 0,
        totalScore: Int = 0,
        bestScore: Int = 0,
        averageScore: Double = 0.0,
        gamesWon: Int = 0,
        createdAt: Date = Date(),
        lastPlayed: Date = Date(),
        avatarImageName: String = PlayerAvatars.defaultName,
        isLocalPlayer: Bool = false
    ) {
        self.id = id
        self.username = username
        self.totalGamesPlayed = totalGamesPlayed
        self.totalScore = totalScore
        self.bestScore = bestScore
        self.averageScore = averageScore
        self.gamesWon = gamesWon
        self.createdAt = createdAt
        self.lastPlayed = lastPlayed
        self.avatarImageName = PlayerAvatars.imageName(for: avatarImageName)
        self.isLocalPlayer = isLocalPlayer
    }
    
    func updateStats(gameScore: Int, won: Bool) {
        totalGamesPlayed += 1
        totalScore += gameScore
        if gameScore > bestScore {
            bestScore = gameScore
        }
        if won {
            gamesWon += 1
        }
        averageScore = totalGamesPlayed > 0 ? Double(totalScore) / Double(totalGamesPlayed) : 0.0
        lastPlayed = Date()
    }
}

// Game message types for Multipeer Connectivity
enum MessageType: String, Codable {
    case invite
    case joinRequest
    case joinAccepted
    case playerJoined
    case playerLeft
    case gameStart
    case question
    case answer
    case roundComplete
    case gameEnd
    case leaderboard
}

struct GameMessage: Codable {
    let type: MessageType
    let data: [String: String]
    let playerID: String?
    let username: String?
    let score: Int?
    let answer: Int?
    let responseTime: TimeInterval?
}

struct ObjectChallenge {
    let objectName: String
    let round: Int
    
    init(objectName: String, round: Int) {
        self.objectName = objectName
        self.round = round
    }
}

