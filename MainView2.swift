//
//  Main2View.swift
//  sbog
//

import SwiftUI
import AVKit

struct Main2: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var multipeerService = MultipeerService()
    @State private var username: String = ""
    @State private var showLobby: Bool = false
    @State private var isHost: Bool = false
    @State private var showUsernameEntry: Bool = false
    @State private var book: Bool = false

    private func goToNextPage() {
        withAnimation(.easeInOut(duration: 0.35)) {
            showUsernameEntry = true
        }
    }

    private func goBackToMainPage() {
        withAnimation(.easeInOut(duration: 0.35)) {
            dismiss()
        }
    }

    var body: some View {
        ZStack {
            Image("s3")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                    ZStack {
                        LoopingVideoPlayer(videoName: "happy")
                            .frame(width: min(geo.size.width * 0.62, 280), height: min(geo.size.width * 1.12, 900))
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.55)

                        Image("stig")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 1.1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .offset(x: -12, y: 160)

                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button("تخطي") {
                                    goToNextPage()
                                }
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 68)
                            .padding(.top, 70)

                            Spacer().frame(height: geo.size.height * 0.10)

                            VStack(spacing: 4) {
                            

                                Text("فعّل البلوتوث عشان تكشف اللي حولك وتسبقهم.")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "84332D"))
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 78)
                            .padding(.top, 54)
                            .offset(x: -22)
                            Spacer()

                            Button {
                                goToNextPage()
                            } label: {
                                Text("إسبق")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(AppTheme.accent)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                            }
                            .padding(.horizontal, 90)
                            .padding(.bottom,36)
                            .offset(x: -14)

                            HStack(spacing: 10) {
                                Button {
                                    goBackToMainPage()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: "F4C7C3"))
                                        .frame(width: 9, height: 9)
                                        .padding(14)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Circle()
                                    .fill(AppTheme.accent)
                                    .frame(width: 9, height: 9)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .padding(.bottom, geo.size.height * 0.06)
                            .offset(x: -14)
                        }

                        NavigationLink(
                            "",
                            destination: UsernameEntryView(
                                username: $username,
                                showLobby: $showLobby,
                                isHost: $isHost,
                                multipeerService: multipeerService
                            ),
                            isActive: $showUsernameEntry
                        )
                        .hidden()

                        Image("logo1")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .offset(y: geo.size.height * 0.30)
                            .opacity(book ? 0.88 : 0)
                            .scaleEffect(book ? 1 : 0.95)
                            .blendMode(.screen)
                            .animation(.easeOut(duration: 2.2), value: book)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        book = true
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    goToNextPage()
                                } else if value.translation.width > 50 {
                                    goBackToMainPage()
                                }
                            }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct Main2_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Main2()
        }
    }
}
