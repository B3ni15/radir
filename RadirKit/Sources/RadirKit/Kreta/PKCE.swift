import CryptoKit
import Foundation

func base64URL(_ data: some DataProtocol) -> String {
    Data(data).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func randomToken(bytes: Int = 32) -> String {
    var g = SystemRandomNumberGenerator()
    return base64URL((0..<bytes).map { _ in UInt8.random(in: .min ... .max, using: &g) })
}

/// RFC 7636, S256. Minden loginnál új kulcs.
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    public static func generate() -> PKCE { PKCE(verifier: randomToken()) }
}
