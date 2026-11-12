import Foundation

/// Egy KRÉTA belépés: a webes login URL-je és a redirect ellenőrzése.
public struct LoginRequest: Sendable {
    public let pkce: PKCE
    public let state: String
    public let nonce: String

    public static func make() -> LoginRequest {
        LoginRequest(pkce: .generate(), state: randomToken(bytes: 16), nonce: randomToken(bytes: 16))
    }

    public var authorizeURL: URL {
        var c = URLComponents(url: Kreta.idp.appending(path: "connect/authorize"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            .init(name: "prompt", value: "login"),
            .init(name: "nonce", value: nonce),
            .init(name: "response_type", value: "code"),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "scope", value: Kreta.scope),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "redirect_uri", value: Kreta.redirectURI),
            .init(name: "client_id", value: Kreta.clientID),
            .init(name: "state", value: state),
        ]
        return c.url!
    }

    /// Az authorization code, ha ez a mi redirectünk, egyező state-tel.
    public func code(from url: URL) -> String? {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let redirect = URLComponents(string: Kreta.redirectURI),
              c.scheme == "https", c.host == redirect.host, c.path == redirect.path else { return nil }
        let q = c.queryItems ?? []
        guard q.first(where: { $0.name == "state" })?.value == state,
              let code = q.first(where: { $0.name == "code" })?.value, !code.isEmpty else { return nil }
        return code
    }
}
