import Foundation

public struct TokenSet: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date

    public init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// 30 mp ráhagyással, mint a legacyban.
    public func isExpired(now: Date) -> Bool { now >= expiresAt.addingTimeInterval(-30) }
}
