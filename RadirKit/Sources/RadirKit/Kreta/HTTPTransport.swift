import Foundation

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KretaError.invalidResponse }
        return (data, http)
    }
}

public enum KretaError: Error, Equatable, Sendable {
    /// A refresh token lejárt vagy visszavonták: újra be kell lépni.
    case reloginRequired
    case http(Int)
    case invalidResponse
}
