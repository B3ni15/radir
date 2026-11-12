import Foundation
@testable import RadirKit

/// Sorban visszaadja a beállított válaszokat, és megjegyzi a kéréseket.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [(Int, Data)]
    private(set) var requests: [URLRequest] = []
    var delay: Duration = .zero

    init(_ responses: [(Int, String)]) {
        self.responses = responses.map { ($0.0, Data($0.1.utf8)) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if delay != .zero { try await Task.sleep(for: delay) }
        let (status, body) = lock.withLock {
            requests.append(request)
            return responses.isEmpty ? (500, Data()) : responses.removeFirst()
        }
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func formBody(_ i: Int) -> [String: String] {
        let s = String(decoding: lock.withLock { requests[i].httpBody } ?? Data(), as: UTF8.self)
        var c = URLComponents(); c.percentEncodedQuery = s
        return Dictionary(uniqueKeysWithValues: (c.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
}

func fakeJWT(_ claims: [String: Any]) -> String {
    let b64 = { (d: Data) in d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    let h = b64(Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8))
    let p = b64(try! JSONSerialization.data(withJSONObject: claims))
    return "\(h).\(p).sig"
}

func tokenJSON(access: String = "acc", refresh: String = "ref", expiresIn: Int = 1800) -> String {
    #"{"access_token":"\#(access)","refresh_token":"\#(refresh)","expires_in":\#(expiresIn),"token_type":"Bearer"}"#
}
