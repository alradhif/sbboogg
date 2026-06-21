//
//  MainPageView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//



import SwiftUI
import AVKit

struct MainPage: View {
    @State private var showMain2: Bool = false
    @State private var ghostsFloating: Bool = false
    
    private func goToNextPage() {
        withAnimation(.easeInOut(duration: 0.35)) {
            showMain2 = true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("s2")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ZStack {
                        // الأشباح — خلف الجمل والنص، تتحرك سوا ذهاباً وإياباً
                        ZStack {
                            Image("ghost1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width * 0.34)
                                .position(x: geo.size.width * 0.10, y: geo.size.height * 0.40)

                            Image("ghost2")
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width * 0.22)
                                .position(x: geo.size.width * 0.80, y: geo.size.height * 0.56)
                        }
                        .offset(
                            x: ghostsFloating ? 16 : -16,
                            y: ghostsFloating ? -8 : 8
                        )
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                                ghostsFloating = true
                            }
                        }

                        LoopingVideoPlayer(videoName: "scared")
                            .frame(width: min(geo.size.width * 0.62, 280), height: min(geo.size.width * 1.12, 400))
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.50)

                        Image("stig")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 1.1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .offset(x: -12, y: 160)

                        Image("ghost3")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.22)
                            .opacity(0.85)
                            .position(x: geo.size.width * 0.44, y: geo.size.height * 0.70)
                            .offset(
                                x: ghostsFloating ? 16 : -16,
                                y: ghostsFloating ? -8 : 8
                            )

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
                            .padding(.top, 20)

                            Spacer().frame(height: geo.size.height * 0.10)

                            VStack(spacing: 4) {
                                Text("الهدوء مو أمان")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "84332D"))

                                Text("دايم في أحد يحاول يسبقك !")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "84332D"))
                            }
                            .multilineTextAlignment(.center)
                            .padding(.top, 64)

                            Spacer()

                            HStack(spacing: 10) {
                                Circle()
                                    .fill(AppTheme.accent)
                                    .frame(width: 9, height: 9)

                                Button {
                                    goToNextPage()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: "F4C7C3"))
                                        .frame(width: 9, height: 9)
                                        .padding(14)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
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
                            destination: Main2(),
                            isActive: $showMain2
                        )
                        .hidden()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                // سحب لليسار = الصفحة التالية (زي السحب)
                                if value.translation.width < -50 {
                                    goToNextPage()
                                }
                            }
                    )
                }
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
    }
}

// فيديو متحرك يتكرر (بدل صورة cry)
struct LoopingVideoPlayer: UIViewControllerRepresentable {
    let videoName: String

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.view.backgroundColor = .clear
        controller.videoGravity = .resizeAspect

        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            return controller
        }

        let player = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
        controller.player = player
        player.play()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }
}

// شكل فقاعة رسالة بذيل (يسار سفلي)
struct ChatBubble: Shape {
    var cornerRadius: CGFloat = 18
    var tailSize: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let tw = tailSize * 1.4
        let th = tailSize
        let cr = min(cornerRadius, (rect.height - th) / 4, rect.width / 4)
        let w = rect.width
        let h = rect.height
        let bodyBottom = h - th

        var path = Path()
        // بداية من أعلى اليسار بعد الانحناء
        path.move(to: CGPoint(x: cr, y: 0))
        path.addLine(to: CGPoint(x: w - cr, y: 0))
        path.addArc(center: CGPoint(x: w - cr, y: cr), radius: cr,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: bodyBottom - cr))
        path.addArc(center: CGPoint(x: w - cr, y: bodyBottom - cr), radius: cr,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: cr + tw, y: bodyBottom))
        path.addLine(to: CGPoint(x: cr, y: h))
        path.addLine(to: CGPoint(x: cr, y: bodyBottom))
        path.addLine(to: CGPoint(x: 0, y: bodyBottom))
        path.addLine(to: CGPoint(x: 0, y: cr))
        path.addArc(center: CGPoint(x: cr, y: cr), radius: cr,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct MainPage_Previews: PreviewProvider {
    static var previews: some View {
        MainPage()
    }
}


//
//import SwiftUI
//
//struct MainPage: View {
//    @StateObject private var multipeerService = MultipeerService()
//    @State private var username: String = ""
//    @State private var showLobby: Bool = false
//    @State private var isHost: Bool = false
//    @State private var showUsernameEntry: Bool = false
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                Color(hex: "FDECC5")
//                    .ignoresSafeArea()
//                
//                // صورة stig1 في الخلفية
//                Image("stig1")
//                    .padding(.bottom, 0)
//                    .offset(x: 00, y: 420)
//                
//                GeometryReader { geo in
//                    VStack(spacing: 0) {
//                        
//                        Spacer()
//                            .frame(height: geo.size.height * 0.10)
//                        
//                        // ====== الشعار في الوسط ======
//                        Image("camel")
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: min(geo.size.width * 0.3, 260), height: min(geo.size.height * 0.42, 200))
//                        
//                        Spacer(minLength: 0)
//                            .frame(height: 0)
//                        
//                        // ====== النص تحت الشعار ======
//                        VStack(spacing: 6) {
//                            Text("كن السبّاق وسجل دخولك")
//                                .font(.system(size: 24, weight: .bold))
//                                .foregroundColor(.black)
//                            
//                            Text("وابدأ اللعب مباشرةً")
//                                .font(.system(size: 24, weight: .bold))
//                                .foregroundColor(.black)
//                        }
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal, 90)
//                        
//                        Spacer()
//                        
//                        // ====== زر (سجل معنا) ======
//                        Button {
//                            showUsernameEntry = true
//                        } label: {
//                            Text("سجل معنا")
//                                .foregroundColor(.white)
//                                .frame(width: min(geo.size.width * 0.5, 290), height: 45)
//                                .background(Color(hex: "84332D"))
//                                .cornerRadius(38)
//                                .font(.system(size: 22, weight: .bold))
//                                .shadow(radius: 6)
//                        }
//                        .padding(.bottom, 330)
//                        .offset(x: 14) // تحريك الزر قليلاً إلى اليمين
//                        
//                        // ====== Navigation Links ======
//                        NavigationLink(
//                            "",
//                            destination: UsernameEntryView(
//                                username: $username,
//                                showLobby: $showLobby,
//                                isHost: $isHost,
//                                multipeerService: multipeerService
//                            ),
//                            isActive: $showUsernameEntry
//                        )
//                        .hidden()
//                        
//                        NavigationLink(
//                            "",
//                            destination: LobbyView(
//                                multipeerService: multipeerService,
//                                isHost: isHost
//                            ),
//                            isActive: $showLobby
//                        )
//                        .hidden()
//                        
//                    }
//                }
//            }
//        }
//    }
//}
//
//struct MainPage_Previews: PreviewProvider {
//    static var previews: some View {
//        MainPage()
//    }
//}
//
