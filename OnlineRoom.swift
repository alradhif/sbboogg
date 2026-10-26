//
//  OnlineRoom.swift
//  sbog
//
//  Online play over Supabase. The room, its players and its rounds live in the
//  database; this class mirrors them into the same GameManager the local game
//  uses, so GameView, the race strip and LeaderboardView work unchanged.
//

import Foundation
import Supabase

struct OnlineRoomRow: Decodable {
    let id: UUID
    let code: String
    let hostID: UUID
    let status: String
    let currentRound: Int
    let totalRounds: Int

    enum CodingKeys: String, CodingKey {
        case id, code, status
        case hostID = "host_id"
        case currentRound = "current_round"
        case totalRounds = "total_rounds"
    }
}

struct OnlinePlayerRow: Decodable, Identifiable {
    let playerID: UUID
    let score: Int
    let isHost: Bool
    let leftAt: Date?
    let profile: Profile

    struct Profile: Decodable {
        let username: String
        let avatarImageName: String?

        enum CodingKeys: String, CodingKey {
            case username
            case avatarImageName = "avatar_image_name"
        }
    }

    var id: UUID { playerID }

    enum CodingKeys: String, CodingKey {
        case score
        case playerID = "player_id"
        case isHost = "is_host"
        case leftAt = "left_at"
        case profile = "profiles"
    }
}

private struct OnlineRoundRow: Decodable {
    let roundNumber: Int
    let challengeID: Int
    let endsAt: Date

    enum CodingKeys: String, CodingKey {
        case roundNumber = "round_number"
        case challengeID = "challenge_id"
        case endsAt = "ends_at"
    }
}

private struct ChallengeRow: Decodable {
    let id: Int
    let nameEn: String

    enum CodingKeys: String, CodingKey {
        case id
        case nameEn = "name_en"
    }
}

private struct CreatedRoom: Decodable {
    let roomID: UUID
    let code: String

    enum CodingKeys: String, CodingKey {
        case code
        case roomID = "room_id"
    }
}

@MainActor
final class OnlineRoom: ObservableObject {
    @Published private(set) var roomID: UUID?
    @Published private(set) var code = ""
    @Published private(set) var isHost = false
    @Published private(set) var status = "lobby"
    @Published private(set) var players: [OnlinePlayerRow] = []
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    weak var gameManager: GameManager?

    private var channel: RealtimeChannelV2?
    private var listeners: [Task<Void, Never>] = []
    private var challengeNames: [Int: String] = [:]
    private var shownRound = 0
    private var advancedRound = 0
    private var roundEndsAt: Date?
    private var roundStartScores: [UUID: Int] = [:]
    private var ticker: Timer?
    private var finished = false
    /// ترتيب اللاعبين النشطين من آخر تحديث (للكشف عن خروج الأول أثناء اللعب).
    private var lastActiveSnapshot: [(id: UUID, score: Int)] = []

    nonisolated var myID: UUID? { supabase.auth.currentUser?.id }
    var activePlayers: [OnlinePlayerRow] { players.filter { $0.leftAt == nil } }
    var canStart: Bool { isHost && status == "lobby" && activePlayers.count >= 2 }

    // MARK: - Lobby actions

    /// Shows the player's local name and avatar to everyone in the room.
    func syncProfile(username: String, avatarImageName: String) async {
        try? await pushProfile(username: username, avatarImageName: avatarImageName)
    }

    func create(username: String, avatarImageName: String) async {
        guard roomID == nil else { return }
        await run {
            try await self.pushProfile(username: username, avatarImageName: avatarImageName)
            let rows: [CreatedRoom] = try await supabase.rpc("create_room").execute().value
            guard let created = rows.first else { throw URLError(.badServerResponse) }
            self.code = created.code
            self.isHost = true
            try await self.enter(created.roomID)
        }
    }

    func join(code: String, username: String, avatarImageName: String) async {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count >= 5, roomID == nil else { return }
        await run {
            try await self.pushProfile(username: username, avatarImageName: avatarImageName)
            let roomID: UUID = try await supabase.rpc("join_room", params: ["p_code": cleaned]).execute().value
            try await self.enter(roomID)
        }
    }

    private func pushProfile(username: String, avatarImageName: String) async throws {
        guard let myID, username.count >= 2 else {
            throw URLError(.userAuthenticationRequired)
        }
        _ = try await supabase.from("profiles")
            .update(["username": String(username.prefix(20)), "avatar_image_name": avatarImageName])
            .eq("id", value: myID.uuidString)
            .execute()
    }

    func start() async {
        guard let roomID else { return }
        await run {
            try await supabase.rpc("start_game", params: ["p_room": roomID.uuidString]).execute()
            try await self.refresh()
        }
    }

    func leave() async {
        guard let roomID else { return }
        if status != "finished" {
            _ = try? await supabase.rpc("leave_room", params: ["p_room": roomID.uuidString]).execute()
        }
        await stopListening()
        self.roomID = nil
        code = ""
        status = "lobby"
        players = []
        shownRound = 0
        advancedRound = 0
        finished = false
        lastActiveSnapshot = []
    }

    // MARK: - In-game

    /// Called when this phone's camera check passes. Returns the points the server gave.
    func submitFind(label: String, confidence: Double) async -> Int? {
        guard let roomID, let round = gameManager?.currentRound, round > 0 else { return nil }
        struct Params: Encodable {
            let p_room: String
            let p_round: Int
            let p_label: String
            let p_confidence: Double
        }
        do {
            let points: Int = try await supabase.rpc(
                "submit_device_find",
                params: Params(p_room: roomID.uuidString, p_round: round, p_label: label, p_confidence: confidence)
            ).execute().value
            try? await refresh()
            return points
        } catch {
            return nil
        }
    }

    // MARK: - Sync with the database

    private func enter(_ roomID: UUID) async throws {
        self.roomID = roomID
        finished = false
        shownRound = 0
        advancedRound = 0
        try await refresh()
        await listen(to: roomID)
        Task { try? await self.loadChallengesIfNeeded() }
    }

    private func noteFirstPlayerDepartureIfNeeded(
        activeBefore: [(id: UUID, score: Int)],
        activeNow: [OnlinePlayerRow]
    ) {
        guard status == "playing",
              let gm = gameManager,
              gm.isGameActive,
              !gm.gameEnded,
              let myID,
              activeBefore.count >= 2 else { return }

        let activeIDs = Set(activeNow.map(\.playerID))
        let firstLeft = !activeIDs.contains(activeBefore[0].id)
        guard firstLeft, activeBefore[1].id == myID else { return }

        gm.applyOpponentLeftNotice(
            myScore: activeBefore[1].score,
            firstPlayerScore: activeBefore[0].score
        )
    }

    private func loadChallengesIfNeeded() async throws {
        guard challengeNames.isEmpty else { return }
        let rows: [ChallengeRow] = try await supabase.from("challenges").select("id, name_en").execute().value
        challengeNames = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.nameEn) })
    }

    private func listen(to roomID: UUID) async {
        await stopListening()
        let channel = supabase.channel("room-\(roomID.uuidString)")
        let id = roomID.uuidString
        let streams = [
            channel.postgresChange(AnyAction.self, schema: "public", table: "rooms", filter: "id=eq.\(id)"),
            channel.postgresChange(AnyAction.self, schema: "public", table: "room_players", filter: "room_id=eq.\(id)"),
            channel.postgresChange(AnyAction.self, schema: "public", table: "room_rounds", filter: "room_id=eq.\(id)"),
        ]
        await channel.subscribe()
        self.channel = channel
        listeners = streams.map { stream in
            Task { [weak self] in
                for await _ in stream {
                    try? await self?.refresh()
                }
            }
        }
    }

    private func stopListening() async {
        listeners.forEach { $0.cancel() }
        listeners = []
        ticker?.invalidate()
        ticker = nil
        if let channel {
            await supabase.removeChannel(channel)
        }
        channel = nil
    }

    private func refresh() async throws {
        guard let roomID else { return }
        let room: OnlineRoomRow = try await supabase.from("rooms")
            .select("id, code, host_id, status, current_round, total_rounds")
            .eq("id", value: roomID.uuidString)
            .single()
            .execute()
            .value
        let rows: [OnlinePlayerRow] = try await supabase.from("room_players")
            .select("player_id, score, is_host, left_at, profiles(username, avatar_image_name)")
            .eq("room_id", value: roomID.uuidString)
            .order("joined_at")
            .execute()
            .value

        code = room.code
        isHost = room.hostID == myID
        status = room.status
        players = rows
        noteFirstPlayerDepartureIfNeeded(activeBefore: lastActiveSnapshot, activeNow: rows.filter { $0.leftAt == nil })
        lastActiveSnapshot = rows.filter { $0.leftAt == nil }.map { ($0.playerID, $0.score) }
        gameManager?.applyOnlinePlayers(activePlayers)

        if room.status == "playing", room.currentRound > shownRound {
            let round: OnlineRoundRow = try await supabase.from("room_rounds")
                .select("round_number, challenge_id, ends_at")
                .eq("room_id", value: roomID.uuidString)
                .eq("round_number", value: room.currentRound)
                .single()
                .execute()
                .value
            showRound(round, totalRounds: room.totalRounds)
        } else if room.status == "playing" {
            advanceIfSomeoneScored()
        } else if room.status == "finished", !finished {
            finished = true
            ticker?.invalidate()
            gameManager?.finishOnlineGame(myKey: myID?.uuidString)
        }
    }

    private func showRound(_ round: OnlineRoundRow, totalRounds: Int) {
        shownRound = round.roundNumber
        roundEndsAt = round.endsAt
        roundStartScores = Dictionary(uniqueKeysWithValues: activePlayers.map { ($0.playerID, $0.score) })
        let name = challengeNames[round.challengeID] ?? "book"
        gameManager?.showOnlineRound(number: round.roundNumber, objectName: name, secondsLeft: secondsLeft())

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func secondsLeft() -> Int {
        guard let roundEndsAt else { return 0 }
        return max(0, Int(ceil(roundEndsAt.timeIntervalSinceNow)))
    }

    private func tick() {
        let left = secondsLeft()
        gameManager?.timeRemaining = left
        if left == 0 {
            ticker?.invalidate()
            advance(after: 1.5)
        }
    }

    /// Like the local game, the round moves on soon after the first find.
    private func advanceIfSomeoneScored() {
        let someoneScored = activePlayers.contains { $0.score > (roundStartScores[$0.playerID] ?? 0) }
        if someoneScored { advance(after: 1.2) }
    }

    /// Only the host opens the next round, once per round. After the last round the
    /// server finishes the game and everyone sees the results through Realtime.
    private func advance(after delay: TimeInterval) {
        guard isHost, let roomID, advancedRound < shownRound else { return }
        let round = shownRound
        advancedRound = round
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.shownRound == round else { return }
            _ = try? await supabase.rpc("next_round", params: ["p_room": roomID.uuidString]).execute()
            try? await self.refresh()
        }
    }

    private func run(_ action: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await action()
        } catch {
            if roomID != nil, code.isEmpty {
                roomID = nil
                isHost = false
            }
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        let text = String(describing: error)
        if text.contains("room_not_found") { return "ما لقينا غرفة بهالكود، أو اللعبة بدأت." }
        if text.contains("room_full") { return "الغرفة مليانة (٥ لاعبين)." }
        if text.contains("need_at_least_2_players") { return "لازم لاعبين على الأقل." }
        if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
            return "جاري تسجيل الدخول… حاول بعد ثانية."
        }
        if !SupabaseConfig.isConfigured { return "حط رابط Supabase والمفتاح في AuthService.swift أول." }
        return "صار خطأ، حاول مرة ثانية."
    }
}

// MARK: - GameManager bridge

extension GameManager {
    /// Keeps the same Player objects so the race strip animates score changes.
    func applyOnlinePlayers(_ rows: [OnlinePlayerRow]) {
        let keys = Set(rows.map { $0.playerID.uuidString })
        players.removeAll { !keys.contains($0.peerID) }
        for row in rows {
            let key = row.playerID.uuidString
            let avatar = PlayerAvatars.imageName(for: row.profile.avatarImageName)
            if let player = players.first(where: { $0.peerID == key }) {
                player.score = row.score
                player.username = row.profile.username
                player.avatarImageName = avatar
            } else {
                players.append(Player(username: row.profile.username, score: row.score,
                                      isHost: row.isHost, peerID: key, avatarImageName: avatar))
            }
        }
        leaderboard = players.sorted { $0.score > $1.score }
        objectWillChange.send()
    }

    func showOnlineRound(number: Int, objectName: String, secondsLeft: Int) {
        isGameActive = true
        gameEnded = false
        currentRound = number
        currentChallenge = ObjectChallenge(objectName: objectName, round: number)
        timeRemaining = secondsLeft
    }

    func finishOnlineGame(myKey: String?) {
        isGameActive = false
        leaderboard = players.sorted { $0.score > $1.score }
        if let me = players.first(where: { $0.peerID == myKey }) {
            let won = leaderboard.first?.score == me.score && me.score > 0
            recordOnlineResult(score: me.score, won: won)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.gameEnded = true
        }
    }
}
