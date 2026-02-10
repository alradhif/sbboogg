//
//  sbogApp.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import SwiftUI
import SwiftData

@main
struct sbogApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Player.self,
            GameSession.self,
            PlayerProfile.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Splash()
        }
        .modelContainer(sharedModelContainer)
    }
}

