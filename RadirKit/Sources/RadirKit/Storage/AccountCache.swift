import Foundation

/// Fiókonkénti JSON gyorsítótár, hogy offline is látszódjon az utolsó állapot.
public struct AccountCache: Sendable {
    let root: URL

    public init(root: URL) { self.root = root }

    private func folder(_ accountID: String) -> URL {
        root.appending(path: accountID.replacingOccurrences(of: "/", with: "_"), directoryHint: .isDirectory)
    }

    public func load<T: Decodable>(_ type: T.Type, as name: String, for accountID: String) -> T? {
        guard let data = try? Data(contentsOf: folder(accountID).appending(path: "\(name).json")) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func save<T: Encodable>(_ value: T, as name: String, for accountID: String) throws {
        let dir = folder(accountID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: dir.appending(path: "\(name).json"),
                                             options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Kijelentkezéskor.
    public func removeAll(for accountID: String) {
        try? FileManager.default.removeItem(at: folder(accountID))
    }
}
