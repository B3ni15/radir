import Foundation

/// A fiókok listája és a kiválasztott fiók egy JSON fájlban; a tokenek külön, a `TokenStore`-ban.
public final class AccountStore {
    private struct Stored: Codable {
        var accounts: [Account]
        var selectedID: String?
    }

    private let fileURL: URL
    public let tokens: any TokenStore
    public private(set) var accounts: [Account]
    public var selectedID: String? {
        didSet { try? persist() }
    }

    public init(fileURL: URL, tokens: any TokenStore) {
        self.fileURL = fileURL
        self.tokens = tokens
        // Sérült vagy hiányzó fájlnál üresen indulunk: a felhasználó újra belép, adat nem vész el a KRÉTA-ban
        let stored = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        accounts = stored?.accounts ?? []
        selectedID = stored?.selectedID
    }

    public var selected: Account? { accounts.first { $0.id == selectedID } }

    /// Új fiók, vagy ugyanannak a felhasználónak az újbóli belépése. Kiválasztja.
    public func upsert(_ account: Account, tokens newTokens: TokenSet?) throws {
        if let newTokens { try tokens.save(newTokens, for: account.id) }
        var account = account
        account.needsRelogin = false
        if let i = accounts.firstIndex(where: { $0.id == account.id }) { accounts[i] = account } else { accounts.append(account) }
        selectedID = account.id
    }

    public func remove(id: String) throws {
        try tokens.delete(id: id)
        accounts.removeAll { $0.id == id }
        if selectedID == id { selectedID = accounts.last?.id } else { try persist() }
    }

    public func markNeedsRelogin(id: String) throws {
        guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[i].needsRelogin = true
        try persist()
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Stored(accounts: accounts, selectedID: selectedID)).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
