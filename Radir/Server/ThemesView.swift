import RadirKit
import SwiftUI

/// Témák: galéria, letöltés kóddal, a saját színek megosztása, saját témák törlése.
struct ThemesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var gallery: [RadirServer.SharedTheme]?
    @State private var mine: [RadirServer.SharedTheme] = []
    @State private var code = ""
    @State private var shareName = ""
    @State private var sharePublic = true
    @State private var sharedCode: String?
    @State private var status: LocalizedStringKey?
    @State private var working = false
    private let server = RadirServer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PanelGroup(title: "Téma kóddal") {
                    HStack {
                        TextField("pl. AbC123xyz789", text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Betöltés") { Task { await apply(id: code.trimmingCharacters(in: .whitespaces)) } }
                            .disabled(code.count < 6 || working)
                    }
                    .padding(14)
                }

                PanelGroup(title: "A jelenlegi színeim megosztása") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("A téma neve", text: $shareName)
                        Toggle("Megjelenik a galériában", isOn: $sharePublic)
                        Button {
                            Task { await share() }
                        } label: {
                            Label("Megosztás", systemImage: "square.and.arrow.up").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .radirProminentButton()
                        .disabled(shareName.trimmingCharacters(in: .whitespaces).isEmpty || working || app.current?.isDemo == true)
                        if app.current?.isDemo == true {
                            Text("Demó fiókkal nem lehet témát megosztani.").font(.footnote).foregroundStyle(Color(palette.secondaryText))
                        }
                        if let sharedCode {
                            HStack {
                                Text("Kód: \(sharedCode)").font(.body.monospaced().weight(.semibold)).textSelection(.enabled)
                                Spacer()
                                ShareLink(item: sharedCode) { Image(systemName: "square.and.arrow.up") }
                            }
                        }
                    }
                    .padding(14)
                }

                if !mine.isEmpty {
                    PanelGroup(title: "Megosztott témáim") {
                        ForEach(mine) { t in
                            HStack {
                                ThemeSwatch(theme: t)
                                VStack(alignment: .leading) {
                                    Text(t.displayName).font(.body.weight(.semibold))
                                    Text(t.publicID).font(.caption.monospaced()).foregroundStyle(Color(palette.secondaryText))
                                }
                                Spacer()
                                Button("Törlés", systemImage: "trash", role: .destructive) { Task { await delete(t) } }.labelStyle(.iconOnly)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Galéria")
                    if let gallery {
                        if gallery.isEmpty {
                            PanelGroup { PanelRow("Még nincs megosztott téma", systemImage: "paintpalette") }
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(gallery) { t in
                                Button { Task { await apply(t) } } label: { ThemeCard(theme: t) }.buttonStyle(.plain)
                            }
                        }
                    } else {
                        PanelGroup { PanelRow("A galéria nem érhető el", subtitle: "Nincs internet, vagy a szerver nem válaszol.", systemImage: "wifi.slash") }
                    }
                }

                if let status {
                    Text(status).font(.footnote).foregroundStyle(Color(palette.secondaryText)).padding(.horizontal, 6)
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Témák")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func token() async -> String? {
        guard let a = app.current, !a.isDemo, let s = app.session(for: a) else { return nil }
        return try? await s.accessToken()
    }

    private func load() async {
        gallery = try? await server.publicThemes()
        if let t = await token() { mine = (try? await server.mine(token: t).themes) ?? [] }
    }

    private func apply(id: String) async {
        working = true; defer { working = false }
        do { await apply(try await server.theme(id)) } catch { status = "Nincs ilyen kódú téma." }
    }

    /// A téma színei a saját színek közé kerülnek; a jegyszínek, ha a témához tartoznak.
    private func apply(_ t: RadirServer.SharedTheme) async {
        let p = app.prefs
        p.customColors = ["accent": t.accentColor, "background": t.backgroundColor, "surface": t.panelsColor, "text": t.iconColor]
        p.customEnabled = true
        if t.themeMode == "dark" { p.appearance = .dark } else if t.themeMode == "light" { p.appearance = .light }
        if let gid = t.gradeColorsID, let g = try? await server.gradeColors(gid) { p.gradeColors = g.colors }
        status = "Beállítva: \(t.displayName)"
    }

    private func share() async {
        guard let token = await token() else { status = "Ehhez be kell jelentkezned a KRÉTA fiókoddal."; return }
        working = true; defer { working = false }
        let p = app.prefs.palette(for: .light)
        do {
            var gid: String?
            if let g = app.prefs.gradeColors {
                gid = try await server.upload(RadirServer.SharedGradeColors(isPublic: sharePublic, nickname: app.current?.student.name ?? "", colors: g), token: token)
            }
            let theme = RadirServer.SharedTheme(isPublic: sharePublic, nickname: app.current?.student.name.split(separator: " ").last.map(String.init) ?? "",
                                                displayName: shareName, background: p.background.value, panels: p.surface.value,
                                                accent: p.accent.value, icon: p.text.value,
                                                themeMode: app.prefs.appearance == .system ? nil : app.prefs.appearance.rawValue, gradeColorsID: gid)
            sharedCode = try await server.upload(theme, token: token)
            await load()
        } catch KretaError.http(429) {
            status = "Túl sok megosztás egy órán belül, próbáld később."
        } catch {
            status = "Nem sikerült megosztani."
        }
    }

    private func delete(_ t: RadirServer.SharedTheme) async {
        guard let token = await token() else { return }
        if (try? await server.deleteTheme(t.publicID, token: token)) != nil { mine.removeAll { $0.id == t.id } }
    }
}

struct ThemeSwatch: View {
    let theme: RadirServer.SharedTheme
    var body: some View {
        ZStack {
            Circle().fill(Color(ARGB(theme.backgroundColor)))
            Circle().fill(Color(ARGB(theme.panelsColor))).padding(7)
            Circle().fill(Color(ARGB(theme.accentColor))).frame(width: 12, height: 12)
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().strokeBorder(.secondary.opacity(0.3)))
        .accessibilityHidden(true)
    }
}

struct ThemeCard: View {
    let theme: RadirServer.SharedTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10).fill(Color(ARGB(theme.panelsColor))).frame(height: 26)
                .overlay(alignment: .leading) { Capsule().fill(Color(ARGB(theme.accentColor))).frame(width: 40, height: 8).padding(.leading, 8) }
            Text(theme.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Color(ARGB(theme.iconColor))).lineLimit(1)
            Text(theme.nickname).font(.caption).foregroundStyle(Color(ARGB(theme.iconColor)).opacity(0.7)).lineLimit(1)
        }
        .padding(12)
        .background(Color(ARGB(theme.backgroundColor)), in: .rect(cornerRadius: 18, style: .continuous))
    }
}
