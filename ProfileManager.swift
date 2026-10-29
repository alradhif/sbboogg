//
//  ProfileManager.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import Foundation
import SwiftData

class ProfileManager: ObservableObject {
    private static let migrationKey = "didMarkLocalProfile"
    private var modelContext: ModelContext?
    
    /// The profile of whoever uses this device. Never another player's.
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
        
        if let local = fetchLocalProfile(in: context) {
            currentProfile = local
            return
        }
        
        // Older installs saved every player of a game as a profile and picked the
        // most recently played one, which could be a friend's. The device owner
        // always sets up their profile before playing, so the oldest row is theirs.
        // Runs once, so a player who logged out is not logged back in.
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.migrationKey) else { return }
        defaults.set(true, forKey: Self.migrationKey)
        let descriptor = FetchDescriptor<PlayerProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        do {
            if let oldest = try context.fetch(descriptor).first {
                oldest.isLocalPlayer = true
                try context.save()
                currentProfile = oldest
            }
        } catch {
            print("Error loading profile: \(error)")
        }
    }
    
    /// Returns this device's profile, creating it on first use.
    /// If a local profile already exists under another name, it is renamed.
    func getOrCreateLocalProfile(username: String) -> PlayerProfile {
        guard let context = modelContext else {
            // Fallback if no context
            return PlayerProfile(username: username, isLocalPlayer: true)
        }
        
        if let local = currentProfile ?? fetchLocalProfile(in: context) {
            if local.username != username {
                local.username = username
            }
            local.isLocalPlayer = true
            currentProfile = local
            save(context)
            return local
        }
        
        // Coming back after logging out: reuse the stats saved under this name.
        if let existing = fetchProfile(username: username, in: context) {
            existing.isLocalPlayer = true
            currentProfile = existing
            save(context)
            return existing
        }
        
        let newProfile = PlayerProfile(username: username, isLocalPlayer: true)
        context.insert(newProfile)
        currentProfile = newProfile
        save(context)
        return newProfile
    }
    
    /// Records a finished game for the player on this device.
    func recordLocalResult(gameScore: Int, won: Bool) {
        guard let context = modelContext else { return }
        if currentProfile == nil {
            loadCurrentProfile()
        }
        guard let profile = currentProfile else { return }
        profile.updateStats(gameScore: gameScore, won: won)
        save(context)
    }
    
    /// Records a finished game for another player, for the on-device ranking only.
    /// Does not touch `currentProfile`.
    func recordOpponentResult(username: String, gameScore: Int, won: Bool) {
        guard let context = modelContext else { return }
        let profile: PlayerProfile
        if let existing = fetchProfile(username: username, in: context), !existing.isLocalPlayer {
            profile = existing
        } else {
            profile = PlayerProfile(username: username)
            context.insert(profile)
        }
        profile.updateStats(gameScore: gameScore, won: won)
        save(context)
    }
    
    func updateAvatar(_ avatarImageName: String) {
        guard let profile = currentProfile, let context = modelContext else { return }
        profile.avatarImageName = PlayerAvatars.imageName(for: avatarImageName)
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Error updating avatar: \(error)")
        }
    }
    
    func updateUsername(oldUsername: String, newUsername: String) {
        guard let context = modelContext,
              let profile = currentProfile ?? fetchLocalProfile(in: context) else { return }
        profile.username = newUsername
        currentProfile = profile
        save(context)
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
    
    /// Logging out keeps the stats but stops treating that profile as this device's.
    func clearCurrentProfile() {
        if let profile = currentProfile, let context = modelContext {
            profile.isLocalPlayer = false
            save(context)
        }
        currentProfile = nil
    }
    
    // MARK: - Private
    
    private func fetchLocalProfile(in context: ModelContext) -> PlayerProfile? {
        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate<PlayerProfile> { profile in
                profile.isLocalPlayer == true
            }
        )
        return (try? context.fetch(descriptor))?.first
    }
    
    private func fetchProfile(username: String, in context: ModelContext) -> PlayerProfile? {
        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate<PlayerProfile> { profile in
                profile.username == username
            }
        )
        return (try? context.fetch(descriptor))?.first
    }
    
    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Error saving profile: \(error)")
        }
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
