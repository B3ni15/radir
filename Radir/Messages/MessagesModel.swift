import Foundation
import Observation
import RadirKit

/// Postafiókok, címzettek, üzenetküldés a kiválasztott fiókhoz.
@Observable
final class MessagesModel {
    private(set) var boxes: [MailBox: [KretaMessage]] = [:]
    private(set) var recipients: [MessageRecipient]?
    private var details: [Int: KretaMessage] = [:]
    private var loading: Set<MailBox> = []

    var unreadCount: Int { boxes[.inbox]?.filter { !$0.isRead }.count ?? 0 }

    func load(_ app: AppModel, _ box: MailBox) async {
        guard let account = app.current else { return }
        if account.isDemo {
            if boxes[box] == nil { boxes[box] = Demo.messages(box) }
            return
        }
        if boxes[box] == nil { boxes[box] = app.cache.load([KretaMessage].self, as: "messages-\(box.rawValue)", for: account.id) }
        guard let session = app.session(for: account), !loading.contains(box) else { return }
        loading.insert(box)
        defer { loading.remove(box) }
        let id = account.id
        do {
            let fresh = try await Task { try await MessagingService().list(box, session: session) }.value
            boxes[box] = fresh
            try? app.cache.save(fresh, as: "messages-\(box.rawValue)", for: id)
        } catch KretaError.reloginRequired {
            app.markNeedsRelogin(id)
        } catch {}
    }

    /// A teljes üzenet; megnyitáskor a KRÉTA olvasottnak jelöli, ezt helyben is átvezetjük.
    func detail(_ app: AppModel, _ message: KretaMessage) async throws -> KretaMessage {
        if let d = details[message.id] { return d }
        guard let account = app.current, !account.isDemo, let session = app.session(for: account) else {
            markRead(message)
            return message
        }
        let full = try await Task { try await MessagingService().detail(message.id, box: message.box, session: session) }.value
        details[message.id] = full
        markRead(message)
        return full
    }

    private func markRead(_ message: KretaMessage) {
        guard var list = boxes[message.box], let i = list.firstIndex(where: { $0.id == message.id }), !list[i].isRead else { return }
        let m = list[i]
        list[i] = KretaMessage(id: m.id, box: m.box, isRead: true, date: m.date, sender: m.sender, subject: m.subject, hasAttachments: m.hasAttachments,
                               text: m.text, recipients: m.recipients, attachments: m.attachments)
        boxes[message.box] = list
    }

    func loadRecipients(_ app: AppModel) async {
        guard recipients == nil, let account = app.current else { return }
        if account.isDemo { recipients = Demo.recipients; return }
        guard let session = app.session(for: account) else { return }
        recipients = try? await Task { try await MessagingService().recipients(session: session) }.value
    }

    func send(_ app: AppModel, to: [MessageRecipient], subject: String, text: String) async throws {
        guard let account = app.current else { return }
        if account.isDemo {
            // demóban semmi nem megy ki, csak az Elküldött mappába kerül
            if boxes[.sent] == nil { boxes[.sent] = Demo.messages(.sent) }
            let m = KretaMessage(id: Int.random(in: 3000..<9000), box: .sent, isRead: true, date: .now, sender: account.student.name,
                                 subject: subject.isEmpty ? String(localized: "Nincs tárgy") : subject, text: text,
                                 recipients: to.map(\.name), attachments: [])
            boxes[.sent, default: []].insert(m, at: 0)
            return
        }
        guard let session = app.session(for: account) else { return }
        try await MessagingService().send(to: to, subject: subject, text: text, senderName: account.student.name,
                                          isParent: account.role == .parent, session: session)
        await load(app, .sent)
    }

    /// Letölti a csatolmányt egy ideiglenes fájlba, hogy előnézetben megnyitható legyen.
    func attachmentFile(_ app: AppModel, _ attachment: MessageAttachment) async throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "attachments-\(attachment.id)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: attachment.name.isEmpty ? "csatolmany" : attachment.name)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let data: Data
        if let account = app.current, !account.isDemo, let session = app.session(for: account) {
            data = try await MessagingService().attachment(attachment.id, session: session)
        } else {
            data = Data("Demó csatolmány – a valódi fiókban itt a KRÉTA-ból letöltött fájl nyílik meg.".utf8)
            return try { let u = url.deletingPathExtension().appendingPathExtension("txt"); try data.write(to: u); return u }()
        }
        try data.write(to: url, options: .completeFileProtection)
        return url
    }
}
