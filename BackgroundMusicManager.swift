//
//  BackgroundMusicManager.swift
//  sbog
//
//  Created for background music management
//

import AVFoundation
import Foundation

class BackgroundMusicManager: ObservableObject {
    static let shared = BackgroundMusicManager()
    
    private var audioPlayer: AVAudioPlayer?
    @Published var isMuted: Bool = false
    @Published var volume: Float = 0.5 {
        didSet {
            audioPlayer?.volume = isMuted ? 0.0 : volume
            UserDefaults.standard.set(volume, forKey: "backgroundMusicVolume")
        }
    }
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Load saved settings from UserDefaults
        isMuted = UserDefaults.standard.bool(forKey: "backgroundMusicMuted")
        volume = UserDefaults.standard.object(forKey: "backgroundMusicVolume") as? Float ?? 0.5
    }
    
    func startBackgroundMusic() {
        guard audioPlayer == nil else {
            // Already playing, just update volume
            audioPlayer?.volume = isMuted ? 0.0 : volume
            return
        }
        
        guard let path = Bundle.main.path(forResource: "gameplaybackground", ofType: "mp3") else {
            print("Error: Could not find gameplaybackground.mp3")
            return
        }
        
        do {
            let url = URL(fileURLWithPath: path)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = isMuted ? 0.0 : volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("✅ Background music started")
        } catch {
            print("Error playing background music: \(error.localizedDescription)")
        }
    }
    
    func stopBackgroundMusic() {
        audioPlayer?.stop()
        audioPlayer = nil
        print("⏹️ Background music stopped")
    }
    
    func pauseBackgroundMusic() {
        audioPlayer?.pause()
    }
    
    func resumeBackgroundMusic() {
        audioPlayer?.play()
    }
    
    func setMuted(_ muted: Bool) {
        isMuted = muted
        audioPlayer?.volume = muted ? 0.0 : volume
        UserDefaults.standard.set(muted, forKey: "backgroundMusicMuted")
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume)) // Clamp between 0 and 1
        audioPlayer?.volume = isMuted ? 0.0 : volume
        UserDefaults.standard.set(volume, forKey: "backgroundMusicVolume")
    }
}

