//
//  ProfileManager.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import Foundation
import SwiftData

class ProfileManager: ObservableObject {
    private var modelContext: ModelContext?
    
    @Published var currentProfile: PlayerProfile?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadCurrentProfile()
    }
    
    func loadCurrentProfile() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<PlayerProfile>(
            sortBy: [SortDescriptor(\.lastPlayed, order: .reverse)]
        )
        
        do {
            let profiles = try context.fetch(descriptor)
            // Get the most recently used profile, or create a default one
            if let profile = profiles.first {
                currentProfile = profile
            }
        } catch {
            print("Error loading profile: \(error)")
        }
    }
    
    func getOrCreateProfile(username: String) -> PlayerProfile {
        guard let context = modelContext else {
            // Fallback if no context
            return PlayerProfile(username: username)
        }
        
        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate<PlayerProfile> { profile in
                profile.username == username
            }
        )
        
        do {
            let profiles = try context.fetch(descriptor)
            if let existingProfile = profiles.first {
                currentProfile = existingProfile
                return existingProfile
            }
        } catch {
            print("Error fetching profile: \(error)")
        }
        
        // Create new profile
        let newProfile = PlayerProfile(username: username)
        context.insert(newProfile)
        currentProfile = newProfile
        
        do {
            try context.save()
        } catch {
            print("Error saving profile: \(error)")
        }
        
        return newProfile
    }
    
    func updateProfile(username: String, gameScore: Int, won: Bool) {
        guard let context = modelContext else { return }
        
        let profile = getOrCreateProfile(username: username)
        profile.updateStats(gameScore: gameScore, won: won)
        
        do {
            try context.save()
        } catch {
            print("Error updating profile: \(error)")
        }
    }
    
    func updateUsername(oldUsername: String, newUsername: String) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate<PlayerProfile> { profile in
                profile.username == oldUsername
            }
        )
        
        do {
            let profiles = try context.fetch(descriptor)
            if let profile = profiles.first {
                profile.username = newUsername
                currentProfile = profile
                try context.save()
            }
        } catch {
            print("Error updating username: \(error)")
        }
    }
    
    func getAllProfiles() -> [PlayerProfile] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<PlayerProfile>(
            sortBy: [SortDescriptor(\.bestScore, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching all profiles: \(error)")
            return []
        }
    }
    
    func clearCurrentProfile() {
        currentProfile = nil
    }
}



//
//import Foundation
//import SwiftData
//
//class ProfileManager: ObservableObject {
//    private var modelContext: ModelContext?
//    
//    @Published var currentProfile: PlayerProfile?
//    
//    init(modelContext: ModelContext? = nil) {
//        self.modelContext = modelContext
//    }
//    
//    func setModelContext(_ context: ModelContext) {
//        self.modelContext = context
//        loadCurrentProfile()
//    }
//    
//    func loadCurrentProfile() {
//        guard let context = modelContext else { return }
//        
//        let descriptor = FetchDescriptor<PlayerProfile>(
//            sortBy: [SortDescriptor(\.lastPlayed, order: .reverse)]
//        )
//        
//        do {
//            let profiles = try context.fetch(descriptor)
//            // Get the most recently used profile, or create a default one
//            if let profile = profiles.first {
//                currentProfile = profile
//            }
//        } catch {
//            print("Error loading profile: \(error)")
//        }
//    }
//    
//    func getOrCreateProfile(username: String) -> PlayerProfile {
//        guard let context = modelContext else {
//            // Fallback if no context
//            return PlayerProfile(username: username)
//        }
//        
//        let descriptor = FetchDescriptor<PlayerProfile>(
//            predicate: #Predicate<PlayerProfile> { profile in
//                profile.username == username
//            }
//        )
//        
//        do {
//            let profiles = try context.fetch(descriptor)
//            if let existingProfile = profiles.first {
//                currentProfile = existingProfile
//                return existingProfile
//            }
//        } catch {
//            print("Error fetching profile: \(error)")
//        }
//        
//        // Create new profile
//        let newProfile = PlayerProfile(username: username)
//        context.insert(newProfile)
//        currentProfile = newProfile
//        
//        do {
//            try context.save()
//        } catch {
//            print("Error saving profile: \(error)")
//        }
//        
//        return newProfile
//    }
//    
//    func updateProfile(username: String, gameScore: Int, won: Bool) {
//        guard let context = modelContext else { return }
//        
//        let profile = getOrCreateProfile(username: username)
//        profile.updateStats(gameScore: gameScore, won: won)
//        
//        do {
//            try context.save()
//        } catch {
//            print("Error updating profile: \(error)")
//        }
//    }
//    
//    func updateUsername(oldUsername: String, newUsername: String) {
//        guard let context = modelContext else { return }
//        
//        let descriptor = FetchDescriptor<PlayerProfile>(
//            predicate: #Predicate<PlayerProfile> { profile in
//                profile.username == oldUsername
//            }
//        )
//        
//        do {
//            let profiles = try context.fetch(descriptor)
//            if let profile = profiles.first {
//                profile.username = newUsername
//                currentProfile = profile
//                try context.save()
//            }
//        } catch {
//            print("Error updating username: \(error)")
//        }
//    }
//    
//    func getAllProfiles() -> [PlayerProfile] {
//        guard let context = modelContext else { return [] }
//        
//        let descriptor = FetchDescriptor<PlayerProfile>(
//            sortBy: [SortDescriptor(\.bestScore, order: .reverse)]
//        )
//        
//        do {
//            return try context.fetch(descriptor)
//        } catch {
//            print("Error fetching all profiles: \(error)")
//            return []
//        }
//    }
//    
//    func clearCurrentProfile() {
//        currentProfile = nil
//    }
//}
