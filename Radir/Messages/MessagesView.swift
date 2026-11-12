import QuickLook
import RadirKit
import SwiftUI

/// Üzenetek: Bejövő, Elküldött, Törölt; írás és válasz.
struct MessagesView: View {
    var showsClose = false
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var box: MailBox = .inbox
    @State private var composing: ComposeDraft?

    var body: some View {
        let list = app.messages.boxes[box] ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Mappa", selection: $box) {
                    Text("Bejövő").tag(MailBox.inbox)
                    Text("Elküldött").tag(MailBox.sent)
                    Text("Törölt").tag(MailBox.trash)
                }
                .pickerStyle(.segmented)

                if list.isEmpty {
                    PanelGroup { PanelRow("Nincs üzenet", systemImage: "tray") }
                } else {
                    PanelGroup {
                        ForEach(list) { m in
                            NavigationLink { MessageDetailView(message: m, reply: { composing = $0 }) } label: { MessageRow(message: m) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Üzenetek")
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .cancellationAction) { Button("Bezárás") { dismiss() } }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Új üzenet", systemImage: "square.and.pencil") { composing = ComposeDraft() }
            }
        }
        .refreshable { await app.messages.load(app, box) }
        .task(id: box) { await app.messages.load(app, box) }
        .sheet(item: $composing) { ComposeView(draft: $0) }
    }
}

struct MessageRow: View {
    let message: KretaMessage
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: message.box == .sent ? (message.recipients.first ?? "?") : message.sender, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.box == .sent ? message.recipients.joined(separator: ", ") : message.sender)
                        .font(.subheadline.weight(message.isRead ? .medium : .bold))
                        .foregroundStyle(Color(palette.text))
                        .lineLimit(1)
                    Spacer()
                    Text(relativeDay(message.date, capitalized: true)).font(.caption).foregroundStyle(Color(palette.secondaryText))
                }
                HStack(spacing: 6) {
                    if !message.isRead { Circle().fill(Color(palette.accent)).frame(width: 8, height: 8).accessibilityLabel("Olvasatlan") }
                    Text(message.subject).font(.body.weight(message.isRead ? .regular : .semibold)).lineLimit(1)
                        .foregroundStyle(Color(palette.text))
                    if message.hasAttachments { Image(systemName: "paperclip").font(.caption).foregroundStyle(Color(palette.secondaryText)) }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}

struct MessageDetailView: View {
    let message: KretaMessage
    var reply: ((ComposeDraft) -> Void)?
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var full: KretaMessage?
    @State private var failed = false
    @State private var preview: URL?
    @State private var downloading: Int?

    var body: some View {
        let m = full ?? message
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(m.subject).font(.title(24, relativeTo: .title))
                HStack(spacing: 12) {
                    AvatarView(name: m.sender, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.sender).font(.subheadline.weight(.semibold))
                        Text(m.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Color(palette.secondaryText))
                    }
                }
                if !m.recipients.isEmpty {
                    Text("Címzett: \(m.recipients.joined(separator: ", "))").font(.footnote).foregroundStyle(Color(palette.secondaryText))
                }
                Group {
                    if full == nil && !failed {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        Text(m.plainText.isEmpty ? String(localized: "Az üzenet szövege nem tölthető be.") : m.plainText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .radirPanel()
                if !m.attachments.isEmpty {
                    PanelGroup(title: "Csatolmányok") {
                        ForEach(m.attachments, id: \.id) { a in
                            Button { open(a) } label: {
                                PanelRow(title: LocalizedStringKey(a.name), systemImage: "paperclip") {
                                    if downloading == a.id { ProgressView() } else { Image(systemName: "arrow.down.circle") }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if m.box == .inbox, let reply {
                    Button {
                        reply(ComposeDraft(subject: m.subject.hasPrefix("Re:") ? m.subject : "Re: \(m.subject)", replyTo: m.sender))
                    } label: {
                        Label("Válasz", systemImage: "arrowshape.turn.up.left").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .radirProminentButton()
                    .controlSize(.large)
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { full = try await app.messages.detail(app, message) } catch { failed = true }
        }
        .quickLookPreview($preview)
    }

    private func open(_ a: MessageAttachment) {
        downloading = a.id
        Task {
            defer { downloading = nil }
            preview = try? await app.messages.attachmentFile(app, a)
        }
    }
}

struct ComposeDraft: Identifiable {
    let id = UUID()
    var subject = ""
    /// Válasznál a feladó neve, hogy előre kiválasztható legyen
    var replyTo: String?
}

struct ComposeView: View {
    let draft: ComposeDraft
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var to: [MessageRecipient] = []
    @State private var subject = ""
    @State private var text = ""
    @State private var picking = false
    @State private var sending = false
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PanelGroup {
                        Button { picking = true } label: {
                            PanelRow(title: to.isEmpty ? "Címzett kiválasztása" : LocalizedStringKey(to.map(\.name).joined(separator: ", ")),
                                     systemImage: "person.crop.circle.badge.plus") { Chevron() }
                        }
                        .buttonStyle(.plain)
                        TextField("Tárgy", text: $subject).padding(14)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 240)
                        .radirPanel()
                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Color(palette.warning)).font(.subheadline.weight(.semibold))
                    }
                }
                .padding(16)
            }
            .radirScreenBackground()
            .navigationTitle("Új üzenet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Mégse") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if sending { ProgressView() } else {
                        Button("Küldés", action: send)
                            .disabled(to.isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .sheet(isPresented: $picking) { RecipientPicker(selection: $to) }
            .task {
                subject = draft.subject
                await app.messages.loadRecipients(app)
                if let name = draft.replyTo, let r = app.messages.recipients?.first(where: { $0.name == name }) { to = [r] }
            }
        }
    }

    private func send() {
        sending = true
        errorText = nil
        Task {
            defer { sending = false }
            do {
                try await app.messages.send(app, to: to, subject: subject, text: text)
                dismiss()
            } catch MessagingError.notAllowed {
                errorText = "Az iskolád nem engedi, hogy üzenetet küldj."
            } catch {
                errorText = "Nem sikerült elküldeni. Próbáld újra."
            }
        }
    }
}

struct RecipientPicker: View {
    @Binding var selection: [MessageRecipient]
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            let all = app.messages.recipients ?? []
            let shown = query.isEmpty ? all : all.filter { $0.name.localizedStandardContains(query) }
            List(shown) { r in
                Button {
                    if let i = selection.firstIndex(of: r) { selection.remove(at: i) } else { selection.append(r) }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.name)
                            Text(r.type.code == "IGAZGATOSAG" ? "Igazgatóság" : "Tanár").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selection.contains(r) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .foregroundStyle(.primary)
            }
            .overlay { if app.messages.recipients == nil { ProgressView() } }
            .searchable(text: $query, prompt: "Keresés")
            .navigationTitle("Címzettek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Kész") { dismiss() } } }
        }
    }
}
