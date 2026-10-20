//
//  ContentView.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var multipeerService = MultipeerService()
    @State private var username: String = ""
    @State private var showLobby: Bool = false
    @State private var isHost: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                
                AppTheme.background
                    .ignoresSafeArea()
                
                if showLobby {
                    LobbyView(multipeerService: multipeerService, isHost: isHost, showLobby: $showLobby)
                } else {
                    UsernameEntryView(
                        username: $username,
                        showLobby: $showLobby,
                        isHost: $isHost,
                        multipeerService: multipeerService
                    )
                }
            }
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

