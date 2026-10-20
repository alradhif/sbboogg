//
//  TimerView.swift
//  sbog
//

import SwiftUI

struct TimerView: View {
    @ObservedObject var multipeerService: MultipeerService
    let onFinished: () -> Void
    var onExit: (() -> Void)? = nil

    @State private var countdown: Int = 4
    @State private var showGoWord = false
    @State private var countdownTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            let circleSize = min(geo.size.width * 0.78, 300)

            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    Text("استعد... الشوط بيبدأ :")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 28)
                        .padding(.top, 36)

                    Spacer()

                    countdownRing(circleSize: circleSize)

                    Spacer()
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    private var header: some View {
        HStack {
            GameExitConfirmButton {
                countdownTimer?.invalidate()
                countdownTimer = nil
                onExit?()
            }

            Spacer()

            Image(multipeerService.avatarImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.accent.opacity(0.25), lineWidth: 2))
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }

    private func countdownRing(circleSize: CGFloat) -> some View {
        ZStack {
            if showGoWord {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: circleSize * 0.55, height: circleSize * 0.55)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.accent, lineWidth: 3)
                    )
                    .scaleEffect(showGoWord ? 1 : 0.85)
                    .opacity(showGoWord ? 1 : 0)

                Text("إسبق")
                    .font(.system(size: min(circleSize * 0.17, 48), weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
                    .scaleEffect(showGoWord ? 1 : 0.8)
                    .opacity(showGoWord ? 1 : 0)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "FFC031"), lineWidth: circleSize * 0.196)
                        .frame(width: circleSize, height: circleSize)
                        .opacity(ringOpacity(layer: 0))

                    Circle()
                        .stroke(Color(hex: "FFCF64"), lineWidth: circleSize * 0.152)
                        .frame(width: circleSize * 0.82, height: circleSize)
                        .opacity(ringOpacity(layer: 1))

                    Circle()
                        .stroke(Color(hex: "FFD983"), lineWidth: circleSize * 0.109)
                        .frame(width: circleSize * 0.64, height: circleSize)
                        .opacity(ringOpacity(layer: 2))

                    Circle()
                        .fill(Color(hex: "FDECC5"))
                        .frame(width: circleSize * 0.55, height: circleSize)
                        .opacity(ringOpacity(layer: 3))
                }
                .animation(.easeOut(duration: 0.45), value: countdown)

                Text(arabicNumeral(countdown))
                    .font(.system(size: min(circleSize * 0.27, 76), weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: countdown)
            }
        }
        .animation(.easeOut(duration: 0.35), value: showGoWord)
    }

    private func ringOpacity(layer: Int) -> Double {
        countdown > (3 - layer) ? 1 : 0
    }

    private func arabicNumeral(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func startCountdown() {
        countdown = 4
        countdownTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.invalidate()
                countdownTimer = nil
                showGoWord = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onFinished()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }
}

#Preview {
    TimerView(multipeerService: MultipeerService()) {}
}
