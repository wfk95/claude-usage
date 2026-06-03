import Foundation
import CryptoKit
import AppKit

/// Stored credential for the usage API.
struct OAuthToken: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scopes: [String]

    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }

    static func load() -> OAuthToken? {
        guard let data = Keychain.load() else { return nil }
        return try? JSONDecoder().decode(OAuthToken.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { Keychain.save(data) }
    }
}

enum OAuthError: LocalizedError {
    case server(String)
    case badResponse
    case stateMismatch
    var errorDescription: String? {
        switch self {
        case .server(let m): return m
        case .badResponse: return "Unexpected response from the sign-in server."
        case .stateMismatch: return "Sign-in could not be verified (state mismatch). Please try again."
        }
    }
}

/// Implements the Claude OAuth 2.0 authorization-code + PKCE flow using the
/// public Claude Code client. Uses the manual-copy redirect: the user authorizes
/// in their browser, copies the displayed code, and pastes it back into the app.
final class OAuth {
    // Constants extracted from the Claude CLI. If sign-in ever stops working,
    // these are the values to revisit.
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let authorizeURL = "https://claude.ai/oauth/authorize"
    static let tokenURL = "https://console.anthropic.com/v1/oauth/token"
    static let redirectURI = "https://console.anthropic.com/oauth/code/callback"
    static let scopes = "org:create_api_key user:profile user:inference"
    static let betaHeader = "oauth-2025-04-20"

    private var verifier: String?
    private var state: String?

    /// Build the authorize URL, remember the PKCE verifier + state, and open the
    /// user's browser to begin sign-in.
    func beginSignIn() {
        let verifier = Self.base64URL(Self.randomBytes(32))
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.base64URL(Self.randomBytes(32))
        self.verifier = verifier
        self.state = state

        var comps = URLComponents(string: Self.authorizeURL)!
        comps.queryItems = [
            .init(name: "code", value: "true"),
            .init(name: "client_id", value: Self.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "scope", value: Self.scopes),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        if let url = comps.url { NSWorkspace.shared.open(url) }
    }

    /// Exchange the pasted code (format "code#state" or just "code") for tokens.
    func completeSignIn(pasted raw: String) async throws -> OAuthToken {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "#", maxSplits: 1).map(String.init)
        let code = parts.first ?? trimmed
        let returnedState = parts.count > 1 ? parts[1] : (state ?? "")

        if let expected = state, !returnedState.isEmpty, returnedState != expected {
            throw OAuthError.stateMismatch
        }

        let body: [String: Any] = [
            "grant_type": "authorization_code",
            "code": code,
            "state": returnedState,
            "client_id": Self.clientID,
            "redirect_uri": Self.redirectURI,
            "code_verifier": verifier ?? "",
        ]
        return try await postToken(body)
    }

    /// Use a refresh token to obtain a new access token. Persists the rotated
    /// tokens that come back.
    static func refresh(_ token: OAuthToken) async throws -> OAuthToken {
        guard let refresh = token.refreshToken else { throw OAuthError.badResponse }
        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": clientID,
        ]
        return try await postToken(body, fallbackScopes: token.scopes)
    }

    // MARK: - Token endpoint

    private func postToken(_ body: [String: Any]) async throws -> OAuthToken {
        try await Self.postToken(body, fallbackScopes: [])
    }

    private static func postToken(_ body: [String: Any], fallbackScopes: [String]) async throws -> OAuthToken {
        var req = URLRequest(url: URL(string: tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw OAuthError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = Self.errorMessage(from: data) ?? "Sign-in failed (HTTP \(http.statusCode))."
            throw OAuthError.server(msg)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else {
            throw OAuthError.badResponse
        }
        let expiresIn = (json["expires_in"] as? Double) ?? 3600
        let scopeStr = json["scope"] as? String
        let scopes = scopeStr?.split(separator: " ").map(String.init) ?? fallbackScopes
        let token = OAuthToken(
            accessToken: access,
            refreshToken: (json["refresh_token"] as? String) ?? body["refresh_token"] as? String,
            expiresAt: Date().addingTimeInterval(expiresIn),
            scopes: scopes
        )
        token.save()
        return token
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let d = json["error_description"] as? String { return d }
        if let e = json["error"] as? String { return e }
        if let m = json["message"] as? String { return m }
        return nil
    }

    // MARK: - PKCE helpers

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
