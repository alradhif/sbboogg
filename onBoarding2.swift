//
//  Untitled 2.swift
//  sbog
//
//  Created by roaa on 25/06/1447 AH.
//

import SwiftUI

struct onBoarding2: View {
    
    @State var selectedPage = 0
    @State private var book = false
    private var showNextView = false
    @State private var navigationActive = false

    @State private var isActive=false

    @State private var animateCircle: Bool = false
    
    var body: some View {
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
                        .scaleEffect(animateCircle ? 1: 0.5)
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
                            Image("phone")
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
                            .opacity(0.9)

                        VStack(spacing: 10) {
                            Text("لقيته؟")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("صوره  بسرعه وكون السبوق بالتحدي")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }

                    NavigationLink(destination: MainPage() ) {
                        Text("التالي")
                            .fontWeight(.bold)
                            .font(.system(size:25))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: min(geo.size.width * 0.8, 300), height: 50)
                            .background(AppTheme.surface)
                            .cornerRadius(7)
                            .navigationBarTitle("")
                            .navigationBarHidden(true)
                    }
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct onBoarding2_Previews: PreviewProvider {
    static var previews: some View {
        onBoarding2()
    }
}
