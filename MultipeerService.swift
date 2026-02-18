//
//  MultipeerService.swift
//  sbog
//
//  Created by fai alradhi on 25/06/1447 AH.
//

import Foundation
import MultipeerConnectivity
import Combine

class MultipeerService: NSObject, ObservableObject {
    // Service type must be 1-15 characters, lowercase, alphanumeric and hyphens only
    private let serviceType = "mathquiz"
    let myPeerID: MCPeerID
    private var session: MCSession?
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    
    @Published var connectedPeers: [MCPeerID] = []
    @Published var availablePeers: [AvailablePeer] = []
    @Published var receivedMessage: GameMessage?
    @Published var isHost: Bool = false
    @Published var isConnected: Bool = false
    @Published var pendingInvitationPeerID: MCPeerID?
    
    /// اسم الداعي المعروض في تنبيه الدعوة (من discovery info إن وُجد)، بدل اسم الجهاز مثل "iPhone"
    var pendingInvitationDisplayName: String? {
        guard let peerID = pendingInvitationPeerID else { return nil }
        return availablePeers.first(where: { $0.peerID == peerID })?.username ?? peerID.displayName
    }
    
    var username: String = ""
    var onMessageReceived: ((GameMessage) -> Void)?
    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?
    
    struct AvailablePeer: Identifiable, Equatable {
        let id: String
        let peerID: MCPeerID
        let username: String
        
        init(peerID: MCPeerID, username: String? = nil) {
            self.id = peerID.displayName
            self.peerID = peerID
            self.username = username ?? peerID.displayName
        }
        
        static func == (lhs: AvailablePeer, rhs: AvailablePeer) -> Bool {
            lhs.id == rhs.id && lhs.username == rhs.username
        }
    }
    
    override init() {
        // Create unique display name to avoid collisions when devices have same name
        let deviceName = UIDevice.current.name
        let uniqueID = UUID().uuidString.prefix(8)
        let uniqueDisplayName = "\(deviceName)-\(uniqueID)"
        self.myPeerID = MCPeerID(displayName: uniqueDisplayName)
        print("🆔 Created unique peerID: \(uniqueDisplayName)")
        super.init()
    }
    
    func startHosting(username: String) {
        self.username = username
        print("🔵 Host username set to: \(username)")
        self.isHost = true
        
        // Use .optional encryption for better compatibility with physical devices
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional)
        session?.delegate = self
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["username": username], serviceType: serviceType)
        serviceAdvertiser?.delegate = self
        serviceAdvertiser?.startAdvertisingPeer()
        
        print("🔵 Host started advertising with service type: \(serviceType)")
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        serviceBrowser?.delegate = self
        serviceBrowser?.startBrowsingForPeers()
        
        print("🔵 Host started browsing for peers")
    }
    
    func startBrowsing(username: String) {
        self.username = username
        self.isHost = false
        
        // Use .optional encryption for better compatibility with physical devices
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional)
        session?.delegate = self
        
        // Guests also need to advertise so they can receive invitations from host
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["username": username, "isGuest": "true"], serviceType: serviceType)
        serviceAdvertiser?.delegate = self
        serviceAdvertiser?.startAdvertisingPeer()
        
        print("🟢 Guest started advertising with service type: \(serviceType)")
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        serviceBrowser?.delegate = self
        serviceBrowser?.startBrowsingForPeers()
        
        print("🟢 Guest started browsing for peers")
    }
    
    func stop() {
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceBrowser?.stopBrowsingForPeers()
        session?.disconnect()
        connectedPeers = []
        isConnected = false
    }
    
    func sendMessage(_ message: GameMessage) {
        guard let session = session else { return }
        
        // Send to all connected peers, or broadcast if no peers yet
        let peersToSend = session.connectedPeers.isEmpty ? [] : session.connectedPeers
        
        guard !peersToSend.isEmpty else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: peersToSend, with: .reliable)
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    func sendInvite(to peer: MCPeerID) {
        guard let browser = serviceBrowser else { return }
        browser.invitePeer(peer, to: session!, withContext: nil, timeout: 30)
    }
}

extension MultipeerService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                    print("✅ Connected to: \(peerID.displayName)")
                    print("   My username: '\(self.username)' (isEmpty: \(self.username.isEmpty))")
                    print("   Total connected peers: \(self.connectedPeers.count)")
                    
                    // Send our username to the newly connected peer
                    // Also send to all other connected peers so everyone knows about the new connection
                    if let session = self.session {
                        if self.username.isEmpty {
                            print("⚠️ WARNING: Username is empty! Cannot send playerJoined message")
                        } else {
                            let joinMessage = GameMessage(
                                type: .playerJoined,
                                data: [:],
                                playerID: self.myPeerID.displayName,
                                username: self.username,
                                score: nil,
                                answer: nil,
                                responseTime: nil
                            )
                            do {
                                let data = try JSONEncoder().encode(joinMessage)
                                // Send to the newly connected peer
                                try session.send(data, toPeers: [peerID], with: .reliable)
                                print("📤 Sent username '\(self.username)' to \(peerID.displayName)")
                                
                                // Also broadcast to all other connected peers so they know about this new connection
                                let otherPeers = self.connectedPeers.filter { $0 != peerID && $0 != self.myPeerID }
                                if !otherPeers.isEmpty {
                                    try session.send(data, toPeers: otherPeers, with: .reliable)
                                    print("📤 Broadcasted username '\(self.username)' to \(otherPeers.count) other peers")
                                }
                            } catch {
                                print("❌ Error sending username: \(error)")
                            }
                        }
                    } else {
                        print("⚠️ WARNING: Session is nil!")
                    }
                }
                self.isConnected = true
            case .connecting:
                print("🔄 Connecting to: \(peerID.displayName)")
            case .notConnected:
                print("❌ Disconnected from: \(peerID.displayName)")
                self.connectedPeers.removeAll { $0 == peerID }
                if self.connectedPeers.isEmpty {
                    self.isConnected = false
                }
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        // Accept all certificates for easier connection on physical devices
        certificateHandler(true)
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)
            DispatchQueue.main.async {
                self.receivedMessage = message
                self.onMessageReceived?(message)
            }
        } catch {
            print("Error decoding message: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            print("📨 Received invitation from: \(peerID.displayName)")
            if self.isHost {
                // Host auto-accepts invitations from guests (up to 4 guests)
                if self.connectedPeers.count < 4 {
                    print("✅ Host accepting invitation from \(peerID.displayName)")
                    invitationHandler(true, self.session)
                } else {
                    print("❌ Host rejecting invitation - too many players")
                    invitationHandler(false, nil)
                }
            } else {
                // Guests receive invitation - show alert to accept/reject
                print("📬 Guest received invitation from \(peerID.displayName)")
                self.pendingInvitationPeerID = peerID
                self.pendingInvitationHandler = invitationHandler
            }
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ Advertiser error: \(error.localizedDescription)")
    }
    
    func acceptInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(true, session)
        pendingInvitationPeerID = nil
        pendingInvitationHandler = nil
    }
    
    func rejectInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(false, nil)
        pendingInvitationPeerID = nil
        pendingInvitationHandler = nil
    }
}

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            // Only add if not already connected and not self
            let isNotConnected = !self.connectedPeers.contains(peerID)
            let isNotSelf = peerID != self.myPeerID
            
            if isNotConnected && isNotSelf {
                // Get username from discovery info
                let username = info?["username"] ?? peerID.displayName
                
                // Check if peer already exists
                if let existingIndex = self.availablePeers.firstIndex(where: { $0.peerID == peerID }) {
                    // Update existing peer with new username if available
                    if let newUsername = info?["username"], newUsername != self.availablePeers[existingIndex].username {
                        self.availablePeers[existingIndex] = AvailablePeer(peerID: peerID, username: newUsername)
                        print("📱 Updated peer: \(peerID.displayName) with username: \(newUsername)")
                    }
                } else {
                    // Add new peer
                    let availablePeer = AvailablePeer(peerID: peerID, username: username)
                    self.availablePeers.append(availablePeer)
                    print("📱 Found peer: \(peerID.displayName) with username: \(username)")
                    print("📱 Total available peers: \(self.availablePeers.count)")
                    if let info = info {
                        print("   Discovery info: \(info)")
                    }
                }
                
                // Guests should NOT auto-invite - they wait for host to invite them
                // This allows host to see and manually invite players
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availablePeers.removeAll { $0.peerID == peerID }
            print("📱 Lost peer: \(peerID.displayName)")
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Browser error: \(error.localizedDescription)")
    }
}

