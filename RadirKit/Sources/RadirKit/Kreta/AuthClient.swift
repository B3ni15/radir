import Foundation

/// A KRÉTA IdP token végpontja: kódcsere, refresh, visszavonás.
public struct AuthClient: Sendable {
    let transport: any HTTPTransport
    let now: @Sendable () -> Date

    public init(transport: any HTTPTransport = URLSessionTransport(), now: @escaping @Sendable () -> Date = Date.init) {
        self.transport = transport
        self.now = now
    }

    public func exchange(code: String, pkce: PKCE) async throws -> TokenSet {
        try await token([
            "code": code,
            "code_verifier": pkce.verifier,
            "redirect_uri": Kreta.redirectURI,
            "client_id": Kreta.clientID,
            "grant_type": "authorization_code",
        ])
    }

    public func refresh(_ refreshToken: String, instituteCode: String) async throws -> TokenSet {
        try await token([
            "refresh_token": refreshToken,
            "institute_code": instituteCode,
            "client_id": Kreta.clientID,
            "grant_type": "refresh_token",
            "refresh_user_data": "false",
        ])
    }

    /// Kijelentkezéskor; a hibát a hívó elnyelheti, a helyi törlés úgyis megtörténik.
    public func revoke(_ refreshToken: String) async throws {
        let (_, res) = try await transport.send(form("connect/revocation", [
            "token": refreshToken, "token_type_hint": "refresh_token", "client_id": Kreta.clientID,
        ]))
        guard (200..<300).contains(res.statusCode) else { throw KretaError.http(res.statusCode) }
    }

    private struct Response: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Double
    }

    private func token(_ fields: [String: String]) async throws -> TokenSet {
        let (data, res) = try await transport.send(form("connect/token", fields))
        if res.statusCode == 400, (try? JSONDecoder().decode([String: String].self, from: data))?["error"] == "invalid_grant" {
            throw KretaError.reloginRequired
        }
        guard (200..<300).contains(res.statusCode) else { throw KretaError.http(res.statusCode) }
        guard let r = try? JSONDecoder().decode(Response.self, from: data) else { throw KretaError.invalidResponse }
        return TokenSet(accessToken: r.access_token, refreshToken: r.refresh_token, expiresAt: now().addingTimeInterval(r.expires_in))
    }

    private func form(_ path: String, _ fields: [String: String]) -> URLRequest {
        var req = URLRequest(url: Kreta.idp.appending(path: path))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue(Kreta.tokenUserAgent, forHTTPHeaderField: "User-Agent")
        var c = URLComponents()
        c.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        // a `+` form-encodingban szóköz lenne, ezért kézzel kódoljuk
        req.httpBody = Data((c.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
        return req
    }
}
