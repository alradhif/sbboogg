//
//  MainPageView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//



import SwiftUI

struct MainPage: View {
    @StateObject private var multipeerService = MultipeerService()
    @State private var username: String = ""
    @State private var showLobby: Bool = false
    @State private var isHost: Bool = false
    @State private var showUsernameEntry: Bool = false
    @State private var displayName: String = "ارحبو"
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(AppTheme.surface)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                        Spacer().frame(height: geo.size.height * 0.05)

                        HStack(spacing: 16) {
                            Image("camel")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 140)

                            Text(displayName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(AppTheme.accentSoft)
                                .clipShape(Capsule())

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        Spacer().frame(height: geo.size.height * 0.06)

                        Text("جاهز؟ سجل دخولك وابدأ اللعب")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Spacer().frame(height: geo.size.height * 0.06)

                        Button {
                            showUsernameEntry = true
                        } label: {
                            Text("دخول")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(AppTheme.accent)
                                    
                            
                        
                                
                                .cornerRadius(28)
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 40)

                        Spacer()

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

                        NavigationLink(
                            "",
                            destination: LobbyView(
                                multipeerService: multipeerService,
                                isHost: isHost
                            ),
                            isActive: $showLobby
                        )
                        .hidden()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
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
