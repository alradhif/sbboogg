//
//  AuthService.swift
//  sbog
//
//  Online sign-in through Supabase: play as a guest, continue with Facebook,
//  or link Facebook to a guest account without losing its stats.
//

import Foundation
import AuthenticationServices
import UIKit
import Supabase

enum SupabaseConfig {
    // Supabase dashboard → Project Settings → API. The anon key is safe to ship in the app.
    static let url = URL(string: "https://rhrssponipcbvvisbppv.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJocnNzcG9uaXBjYnZ2aXNicHB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1MDg1NTIsImV4cCI6MjEwODA4NDU1Mn0.Mk55CH0kXy2mEXpLbf1a7uwlW56HYlFr5yBx6CAO7II"

    // Must match the URL scheme in Info.plist and a Redirect URL in Supabase → Authentication → URL Configuration.
    static let callbackScheme = "sbog"
    static let redirectURL = URL(string: "sbog://login-callback")!

    static var isConfigured: Bool { !url.absoluteString.contains("YOUR-PROJECT-REF") && anonKey != "YOUR-ANON-KEY" }
}

let supabase = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    enum State: Equatable {
        case loading
        case signedOut
        case guest
        case facebook
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private init() {
        Task { await listenForAuthChanges() }
    }

    var userID: UUID? { supabase.auth.currentUser?.id }

    // MARK: - Actions

    func signInAsGuest() async {
        await run { _ = try await supabase.auth.signInAnonymously() }
    }

    /// Ensures Supabase has a session before create/join room RPCs.
    /// Does not toggle `isWorking` so the room code field stays usable.
    func prepareForOnlinePlay() async {
        updateState()
        guard supabase.auth.currentUser == nil else { return }
        do {
            _ = try await supabase.auth.signInAnonymously()
            updateState()
        } catch {
            errorMessage = Self.message(for: error)
            updateState()
        }
    }

    func signInWithFacebook() async {
        await run {
            _ = try await supabase.auth.signInWithOAuth(
                provider: .facebook,
                redirectTo: SupabaseConfig.redirectURL,
                scopes: "public_profile"
            )
        }
    }

    /// Turns the current guest into a Facebook account. The user ID stays the same,
    /// so the profile, علف, camel and accessories all carry over.
    func linkFacebook() async {
        await run {
            let response = try await supabase.auth.getLinkIdentityURL(
                provider: .facebook,
                scopes: "public_profile",
                redirectTo: SupabaseConfig.redirectURL
            )
            let callback = try await WebAuthSession.start(url: response.url, callbackScheme: SupabaseConfig.callbackScheme)
            _ = try await supabase.auth.session(from: callback)
            _ = try await supabase.auth.refreshSession()
            updateState()
        }
    }

    func signOut() async {
        await run { try await supabase.auth.signOut() }
    }

    /// Call from `.onOpenURL` so links that come back through the URL scheme are handled too.
    func handle(_ url: URL) {
        supabase.auth.handle(url)
    }

    // MARK: - Private

    private func listenForAuthChanges() async {
        updateState()
        for await _ in supabase.auth.authStateChanges {
            updateState()
        }
    }

    private func updateState() {
        guard let user = supabase.auth.currentUser else {
            state = .signedOut
            return
        }
        state = user.isAnonymous ? .guest : .facebook
    }

    private func run(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await action()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // The player closed the Facebook page; nothing to show.
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        let text = String(describing: error) + " " + (error as NSError).localizedDescription
        if text.contains("identity_already_exists") || text.contains("already linked") {
            return "حساب الفيسبوك هذا مربوط بلاعب ثاني. سجّل دخول بفيسبوك بدل الربط."
        }
        if text.contains("manual_linking_disabled") {
            return "ربط الحسابات مقفل في Supabase. فعّل Manual linking من إعدادات Authentication."
        }
        if text.contains("anonymous") || text.contains("Anonymous") || text.contains("anonymous_provider_disabled") {
            return "الدخول كضيف مقفل في Supabase. فعّل Anonymous sign-ins من Authentication."
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return "ما فيه نت. تأكد من الاتصال وحاول مرة ثانية."
            default:
                break
            }
        }
        return "ما قدرنا نسجّل دخولك. جرّب «العب كضيف» أو تأكد من النت."
    }
}

// MARK: - ASWebAuthenticationSession as async/await

private final class WebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    @MainActor
    static func start(url: URL, callbackScheme: String) async throws -> URL {
        let holder = WebAuthSession()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? URLError(.badServerResponse))
                }
                holder.session = nil
            }
            session.presentationContextProvider = holder
            holder.session = session
            session.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }
}
