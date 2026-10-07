//
//  on.swift
//  sbog
//
//  Created by roaa on 25/06/1447 AH.
//

import SwiftUI

struct onBoarding1: View {
    
    @State var selectedPage = 0
    @State private var book = false
    private var showNextView = false
    @State private var navigationActive = false
    @State private var isActive=false
   @State private var animateCircle: Bool = false
    @State private var goToUsernameEntry: Bool = false
    @State private var username: String = ""
    @State private var showLobby: Bool = false
    @State private var isHost: Bool = false
    @StateObject private var multipeerService = MultipeerService()
    
    var body: some View {
        NavigationView{
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                GeometryReader { geo in
                    let circleSize = min(geo.size.width * 0.85, 380)
                    let imageSize = min(geo.size.width * 0.45, 190)

                    VStack(spacing: 6) {
                        Spacer().frame(height: geo.size.height * 0.03)

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
                            .onAppear { animateCircle = true }

                            Image("Vector 9")
                                .offset(x: -geo.size.width * 0.35, y: -geo.size.height * 0.12)
                                .opacity(book ? 1 : 0)
                                .scaleEffect(book ? 1 : 0)
                            Image("Vector 8")
                                .offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.08)
                                .scaleEffect(book ? 1 : 0)

                            VStack(spacing: 10) {
                                Image("research")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: imageSize, height: imageSize * 1.1)

                               
                            }
                            .offset(y: geo.size.height * 0.09)
                        }
                        .animation(.easeOut(duration: 2), value: book)
                        .onAppear { book = true }

                        ZStack {
                            Image("Stig3")
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width * 0.7)
                                .opacity(0.9)   // تقدر تعدّل الشفافية لو حاب

                            VStack(spacing: 10) {
                                Text("ركز حواليك")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("نبيك تبحث عن التلميح اسرع منهم")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }
                    

                        NavigationLink(destination: onBoarding2() ) {
                            Text("التالي")
                                .fontWeight(.bold)
                                .font(.system(size: 25))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: min(geo.size.width * 0.8, 300), height: 50)
                                .background(AppTheme.surface)
                                .cornerRadius(7)
                                .navigationBarTitle("")
                                .navigationBarHidden(true)
                        }
                        .padding(.bottom, 0)

                        Button("تخطي") {
                            goToUsernameEntry = true
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.bottom, geo.size.height * 0.04)

                        NavigationLink(
                            destination: UsernameEntryView(
                                username: $username,
                                showLobby: $showLobby,
                                isHost: $isHost,
                                multipeerService: multipeerService
                            ),
                            isActive: $goToUsernameEntry
                        ) {
                            EmptyView()
                        }
                        .hidden()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct onBoarding1_Previews: PreviewProvider {
    static var previews: some View {
        onBoarding1()
    }
}
