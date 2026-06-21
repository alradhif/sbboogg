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
            print("⚠️ ModelContainer load failed: \(error). Resetting local store...")
            Self.deleteStoreFiles(at: modelConfiguration.url)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Splash()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func deleteStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]

        for url in relatedURLs where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}
