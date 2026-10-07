//
//  SwiftUIView1.swift
//  se
//
//  Created by roaa on 01/03/1446 AH.
//

import SwiftUI





struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        Splash()
        
    }
}
struct Splash: View {
    @State var splashScreen  = true
    @State private var isActive = false
    @State private var selectedPage = 0
    @State private var book = false
    private var showNextView = false
    @State private var navigationActive = false
    @State private var animateCircle: Bool = false
    
    var body: some View {
        ZStack {
            
            
            
            
           

            Text("سـبٌوق")
                .font(.system(size: 50))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .overlay(
                    Text("سـبٌوق")
                        .font(.system(size: 50))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "84332D"))
                        .offset(x: 1, y: 1)
                )
                .offset(x: 50, y: -270)
                .rotationEffect(.degrees(-10))

            Group {
                if splashScreen {
                    SplashScreen()
                } else {
                    UsernameEntryView()
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    splashScreen = false
                }
            }
            
        }
    }
}
struct CircleBackground: View {
    @State private var animateCircle = false

    var body: some View {
        ZStack {
            Circle().stroke(Color(hex: "FFCD4D"), lineWidth: 100)
                .frame(width:  400, height:  400 )

            Circle().stroke(Color(hex: "FFD983"), lineWidth:90)
                .frame(width: 350, height: 400, alignment: .center)

            Circle().stroke(Color(hex: "FFD983"), lineWidth: 40)
                .frame(width: 300, height: 400)
        }
        .scaleEffect(animateCircle ? 1 : 0.5)
        .animation(.easeOut(duration: 1.5), value: animateCircle)
        .onAppear {
            animateCircle = true
        }
        .offset(x: -100, y: -130)
    }
}


struct SplashScreen: View {
    @State private var animateOffset = false
    @State private var book = false
    @State private var animateCircle = false
    
    var body: some View {
        ZStack {
            
            HStack {
                Image("Vector 8")
                    .offset(x:50, y: -150)
                    .font(.system(size: 80))
                    .scaleEffect(book ? 1 : 0)
                
                Image("Vector 9")
                    .offset(x:-230, y: -150)
                    .font(.system(size: 30))
                    .scaleEffect(book ? 1 : 0)
                    .opacity(book ? 1 : 0)
            }
            .animation(.easeOut(duration: 2), value: book)
            .onAppear {
                book = true
            }
            .offset(x: 100, y: -30)
            
            ZStack {
                Circle().stroke(Color(hex: "FFCD4D"), lineWidth: 100)
                    .frame(width:  400, height:  400 )
                
                Circle().stroke(Color(hex: "FFD983"), lineWidth:90)
                    .frame(width: 350, height: 400, alignment: .center)
                
                Circle().stroke(Color(hex: "FFD983"), lineWidth: 40)
                    .frame(width: 300, height: 400)
                
            }
            .offset(x: -100, y: -130)
            .scaleEffect(animateCircle ? 1 : 0.5)
            .animation(.easeOut(duration: 1.5), value: animateCircle)
            .onAppear {
                animateCircle = true
            }
            
        }
        .offset(x: 100, y: 150)
        .animation(.easeOut(duration: 2), value: animateOffset)
        .onAppear {
            animateOffset = true
        }
        
        ZStack{
            Image("logo")
                .resizable()
                .frame(width: 300, height: 400)
                .offset(y: 60)
            
            Image("stig1")
                .padding(.bottom, 0)
                .offset(x: 00, y: 260)
            
            Text("سبّاق وقد التحدي؟")
                .font(.system(size: 30))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .overlay(
                    Text("سبّاق وقد التحدي؟")
                        .font(.system(size: 30))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "84332D"))
                        .offset(x: 1, y: 1)
                )
                .offset(x: 0, y: 250)
            
        }
        
        
    }
}

    
    


