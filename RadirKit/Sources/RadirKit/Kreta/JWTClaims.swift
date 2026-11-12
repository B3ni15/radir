import Foundation

public enum Role: String, Codable, Sendable {
    case student = "Tanulo"
    case parent = "Gondviselo"
}

/// A KRÉTA access token tartalma. Az aláírást itt nem ellenőrizzük: a tokent most kaptuk az IdP-től HTTPS-en.
public struct JWTClaims: Sendable, Equatable {
    public let instituteCode: String
    public let userName: String
    public let role: Role
    public let name: String?

    public init(accessToken: String) throws {
        let parts = accessToken.split(separator: ".")
        guard parts.count == 3 else { throw KretaError.invalidResponse }
        var p = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        p += String(repeating: "=", count: (4 - p.count % 4) % 4)
        guard let data = Data(base64Encoded: p),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let institute = json["kreta:institute_code"] as? String,
              let user = json["kreta:user_name"] as? String,
              let role = (json["role"] as? String).flatMap(Role.init(rawValue:))
        else { throw KretaError.invalidResponse }
        instituteCode = institute
        userName = user
        self.role = role
        name = json["name"] as? String
    }
}
