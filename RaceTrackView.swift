//
//  RaceTrackView.swift
//  sbog
//

import SwiftUI

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

    private static func arabicNumeral(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
