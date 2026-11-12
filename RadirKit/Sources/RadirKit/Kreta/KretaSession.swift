import Foundation

/// Hitelesített KRÉTA-kérések egy fiókhoz: lejáratkor és 401-nél frissít, párhuzamos kéréseknél csak egyszer.
public actor KretaSession {
    public let instituteCode: String
    private var tokens: TokenSet
    private let auth: AuthClient
    private let transport: any HTTPTransport
    private let userAgent: String
    private let now: @Sendable () -> Date
    private let onTokensChanged: @Sendable (TokenSet) async -> Void
    private var refreshing: Task<TokenSet, Error>?

    public init(instituteCode: String, tokens: TokenSet, auth: AuthClient, transport: any HTTPTransport,
                userAgent: String, now: @escaping @Sendable () -> Date = Date.init,
                onTokensChanged: @escaping @Sendable (TokenSet) async -> Void) {
        self.instituteCode = instituteCode
        self.tokens = tokens
        self.auth = auth
        self.transport = transport
        self.userAgent = userAgent
        self.now = now
        self.onTokensChanged = onTokensChanged
    }

    public func data(for url: URL) async throws -> Data {
        try await send(URLRequest(url: url))
    }

    /// JSON POST (pl. üzenetküldés).
    public func post(json body: Data, to url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("hu-HU", forHTTPHeaderField: "X-Uzenet-Lokalizacio")
        req.httpBody = body
        return try await send(req)
    }

    /// Hitelesítve elküldi a kérést; lejárt tokennél és 401-nél frissít.
    public func send(_ request: URLRequest) async throws -> Data {
        var token = try await validAccessToken()
        for attempt in 0..<2 {
            var req = request
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (data, res) = try await transport.send(req)
            if res.statusCode == 401, attempt == 0 {
                token = try await refresh(ifStillUsing: token).accessToken
                continue
            }
            guard (200..<300).contains(res.statusCode) else { throw KretaError.http(res.statusCode) }
            return data
        }
        throw KretaError.http(401)
    }

    public func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        do { return try JSONDecoder().decode(T.self, from: try await data(for: url)) }
        catch is DecodingError { throw KretaError.invalidResponse }
    }

    private func validAccessToken() async throws -> String {
        if let refreshing { return try await refreshing.value.accessToken }
        if tokens.isExpired(now: now()) { return try await refresh(ifStillUsing: tokens.accessToken).accessToken }
        return tokens.accessToken
    }

    /// Ha közben egy másik kérés már frissített, nem frissít újra.
    private func refresh(ifStillUsing used: String) async throws -> TokenSet {
        if let refreshing { return try await refreshing.value }
        if tokens.accessToken != used { return tokens }
        let (auth, refreshToken, institute) = (auth, tokens.refreshToken, instituteCode)
        let task = Task { try await auth.refresh(refreshToken, instituteCode: institute) }
        refreshing = task
        defer { refreshing = nil }
        let new = try await task.value
        tokens = new
        await onTokensChanged(new)
        return new
    }
}
