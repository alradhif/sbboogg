import SwiftUI
import SwiftData

struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        Splash()
            .modelContainer(
                for: [Player.self, GameSession.self, PlayerProfile.self],
                inMemory: true
            )
    }
}

struct Splash: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var multipeerService = MultipeerService()
    @StateObject private var profileManager = ProfileManager()
    @State private var username: String = ""
    @State private var showLobby: Bool = false
    @State private var isHost: Bool = false
    @State var splashScreen = true
    @State private var hasProfile = false
    
    var body: some View {
        ZStack {
            Color(hex: "FFCB45")
                .ignoresSafeArea()

            if splashScreen {
                SplashScreen()
            } else if hasProfile {
                NavigationView {
                    UsernameEntryView(
                        username: $username,
                        showLobby: $showLobby,
                        isHost: $isHost,
                        multipeerService: multipeerService
                    )
                }
                .navigationViewStyle(.stack)
            } else {
                MainPage()
            }

            if splashScreen {
                GeometryReader { geo in
                    VStack(spacing: 13) {
                        Spacer().frame(height: geo.size.height * 0.0)

                        Text("سـبٌوق")
                            .font(.appTitle(50))
                            .foregroundColor(AppTheme.textPrimary)
                            .rotationEffect(.degrees(8))
                            .overlay(
                                Text("سـبٌوق")
                                    .font(.appTitle(50))
                                    .foregroundColor(AppTheme.accent)
                                    .offset(x: 1, y: 1)
                                    .rotationEffect(.degrees(8))
                            )

                        Text("سبّاق وقد التحدي")
                            .font(.appTitle(30))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("؟")
                            .font(.appTitle(40))
                            .foregroundColor(AppTheme.textPrimary)
                            .overlay(
                                Text("؟")
                                    .font(.appTitle(40))
                                    .foregroundColor(AppTheme.accent)
                                    .offset(x: 1, y: 1)
                            )

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            profileManager.setModelContext(modelContext)
            hasProfile = profileManager.currentProfile != nil
            if let profile = profileManager.currentProfile {
                username = profile.username
            }

            BackgroundMusicManager.shared.startBackgroundMusic()

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                splashScreen = false
            }
        }
    }
}



struct SplashScreen: View {
    @State private var animateOffset = false
    @State private var book = false
    @State private var animateCircle = false
    
    var body: some View {
        GeometryReader { geo in
            let circleSize = min(geo.size.width * 0.98, 460)
            let imageSize = min(geo.size.width * 0.45, 190)
            ZStack {
                Color(hex: "FFCB45")
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer().frame(height: geo.size.height * 0.27)

                    ZStack {
                        ZStack {
                            Circle()
                                .stroke(Color(hex: "FFC031"), lineWidth: 90)
                                .frame(width: circleSize, height: circleSize)
                            Circle()
                                .stroke(Color(hex: "FFCF64"), lineWidth: 70)
                                .frame(width: circleSize * 0.82, height: circleSize)
                            Circle()
                                .stroke(Color(hex: "FFD983"), lineWidth: 50)
                                .frame(width: circleSize * 0.64, height: circleSize)
                            Circle()
                                .fill(Color(hex: "FDECC5"))
                                .frame(width: circleSize * 0.55, height: circleSize)
                        }
                        .scaleEffect(animateCircle ? 1 : 0.5)
                        .animation(.easeOut(duration: 1.5), value: animateCircle)
                        .offset(x: -18)
                        .onAppear { animateCircle = true }

                        Image("Vector 9")
                            .offset(x: -geo.size.width * 0.35, y: -geo.size.height * 0.24)
                            .opacity(book ? 1 : 0)
                            .scaleEffect(book ? 1 : 0)
                        Image("Vector 8")
                            .offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.30)
                            .scaleEffect(book ? 1 : 0)
                    }
                    .animation(.easeOut(duration: 1), value: book)
                    .onAppear { book = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
               

                Image("stig")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.77) // زيادة بنسبة 10%
                    .padding(.bottom, 0)
                    .offset(x: -12, y: geo.size.height * 0.40)


                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.7)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.57)

                // إضاءة فوق السبلاش كامل
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
                animateCircle = true
            }
        }
    }
}

