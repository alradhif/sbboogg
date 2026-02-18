import SwiftUI

struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        Splash()
    }
}

struct Splash: View {
    @StateObject private var multipeerService = MultipeerService()
    @State private var username: String = ""
    @State private var showLobby: Bool = false
    @State private var isHost: Bool = false
    @State var splashScreen  = true
    @State private var isActive = false
    @State private var selectedPage = 0
    @State private var book = false
    private var showNextView = false
    @State private var navigationActive = false
    @State private var animateCircle: Bool = false
    
    var body: some View {
        ZStack {
            AppTheme.accentSoft
                .ignoresSafeArea()

            if splashScreen {
                SplashScreen()
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
                            .overlay(
                                Text("سـبٌوق")
                                    .font(.appTitle(50))
                                    .foregroundColor(AppTheme.accent)
                                    .offset(x: 1, y: 1)
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
            // Start background music from splash screen
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
            let circleSize = min(geo.size.width * 0.85, 380)
            let imageSize = min(geo.size.width * 0.45, 190)
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer().frame(height: geo.size.height * 0.27)

                    ZStack {
                        ZStack {
                            Circle()
                                .stroke(AppTheme.accentSoft, lineWidth: 80)
                                .frame(width: circleSize, height: circleSize)
                            Circle()
                                .stroke(AppTheme.accentSoftSecondary, lineWidth: 60)
                                .frame(width: circleSize * 0.85, height: circleSize)
                            Circle()
                                .stroke(AppTheme.accentSoftSecondary, lineWidth: 30)
                                .frame(width: circleSize * 0.7, height: circleSize)
                        }
                        .scaleEffect(animateCircle ? 1 : 0.5)
                        .animation(.easeOut(duration: 1.5), value: animateCircle)
                        .offset(x: -18)
                        .onAppear { animateCircle = true }

                        Image("Vector 9")
                            .offset(x: -geo.size.width * 0.35, y: -geo.size.height * 0.12)
                            .opacity(book ? 1 : 0)
                            .scaleEffect(book ? 1 : 0)
                        Image("Vector 8")
                            .offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.08)
                            .scaleEffect(book ? 1 : 0)
                    }
                    .animation(.easeOut(duration: 2), value: book)
                    .onAppear { book = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
               

                Image("stig")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.77) // زيادة بنسبة 10%
                    .padding(.bottom, 0)
                    .offset(x: -12, y: geo.size.height * 0.40)


                Image("logo1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 1.2)
                    .position(x: geo.size.width / 3, y: geo.size.height * 0.08)

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.7)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.57)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                animateCircle = true
            }
        }
    }
}

