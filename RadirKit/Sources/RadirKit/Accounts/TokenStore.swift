import Foundation
import Security

public protocol TokenStore: Sendable {
    func tokens(for id: String) throws -> TokenSet?
    func save(_ tokens: TokenSet, for id: String) throws
    func delete(id: String) throws
}

public enum TokenStoreError: Error { case keychain(OSStatus) }

/// Fiókonként egy Keychain elem. Az első feloldás után háttérben is olvasható (későbbi háttérfrissítéshez).
public struct KeychainTokenStore: TokenStore {
    let service: String

    public init(service: String = "hu.radirapp.ios.tokens") { self.service = service }

    private func query(_ id: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id]
    }

    public func tokens(for id: String) throws -> TokenSet? {
        var q = query(id)
        q[kSecReturnData as String] = true
        var out: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = out as? Data else { throw TokenStoreError.keychain(status) }
        return try JSONDecoder().decode(TokenSet.self, from: data)
    }

    public func save(_ tokens: TokenSet, for id: String) throws {
        let data = try JSONEncoder().encode(tokens)
        let attrs: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(query(id) as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(id).merging(attrs) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw TokenStoreError.keychain(status) }
    }

    public func delete(id: String) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TokenStoreError.keychain(status) }
    }
}

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: TokenSet] = [:]

    public init() {}
    public func tokens(for id: String) throws -> TokenSet? { lock.withLock { items[id] } }
    public func save(_ tokens: TokenSet, for id: String) throws { lock.withLock { items[id] = tokens } }
    public func delete(id: String) throws { _ = lock.withLock { items.removeValue(forKey: id) } }
}
