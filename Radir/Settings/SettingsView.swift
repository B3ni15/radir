import RadirKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var addingAccount = false
    @State private var confirmLogout: Account?
    @State private var showConsent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let current = model.current { profile(current) }

                    PanelGroup(title: "Fiókok") {
                        ForEach(model.accounts) { account in
                            Button { withAnimation(.snappy) { model.select(account.id) } } label: { accountRow(account) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Kijelentkezés", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                                        confirmLogout = account
                                    }
                                }
                        }
                        Button { addingAccount = true } label: {
                            PanelRow("Új fiók hozzáadása", systemImage: "plus")
                        }
                        .buttonStyle(.plain)
                    }

                    PanelGroup(title: "Live Activity") {
                        PanelRow(title: "Óra a zárolt képernyőn", subtitle: "A mostani órád és a visszaszámlálás, akkor is, ha a Radír zárva van.",
                                 systemImage: "platter.filled.top.iphone") {
                            Toggle("Live Activity", isOn: liveActivityBinding).labelsHidden()
                        }
                        if !model.liveActivity.isAllowedBySystem {
                            PanelRow("A rendszerbeállításokban ki van kapcsolva",
                                     subtitle: "Beállítások → Radír → Live Activityk", systemImage: "exclamationmark.triangle",
                                     tint: Color(palette.warning))
                        }
                    }
                    .sheet(isPresented: $showConsent) {
                        LiveActivityConsent {
                            if let id = model.current?.id { model.liveActivity.setEnabled(true, for: id) }
                            showConsent = false
                            Task { await model.liveActivity.sync(app: model, now: model.prefs.schoolNow) }
                        } cancel: { showConsent = false }
                    }

                    PanelGroup(title: "Beállítások") {
                        NavigationLink { AppearanceSettingsView() } label: {
                            PanelRow(title: "Megjelenés", subtitle: "Téma, akcentus, jegyszínek", systemImage: "paintpalette") { Chevron() }
                        }.buttonStyle(.plain)
                        NavigationLink { GeneralSettingsView() } label: {
                            PanelRow(title: "Általános", subtitle: "Kezdőoldal, kerekítés, csengetés", systemImage: "gearshape") { Chevron() }
                        }.buttonStyle(.plain)
                        NavigationLink { RenameSettingsView() } label: {
                            PanelRow(title: "Átnevezés", subtitle: "Tantárgyak és tanárok saját neve", systemImage: "character.cursor.ibeam") { Chevron() }
                        }.buttonStyle(.plain)
                        NavigationLink { ThemesView() } label: {
                            PanelRow(title: "Témák", subtitle: "Galéria, megosztás kóddal", systemImage: "swatchpalette") { Chevron() }
                        }.buttonStyle(.plain)
                        NavigationLink { ToolsSettingsView() } label: {
                            PanelRow(title: "Naptár és export", systemImage: "calendar.badge.plus") { Chevron() }
                        }.buttonStyle(.plain)
                    }

                    PanelGroup(title: "Egyéb") {
                        NavigationLink { NewsView() } label: {
                            PanelRow(title: "Hírek", systemImage: "newspaper") { Chevron() }
                        }.buttonStyle(.plain)
                        if let current = model.current {
                            NavigationLink { StudentInfoView(account: current) } label: {
                                PanelRow(title: "Személyes adatok", systemImage: "person.text.rectangle") { Chevron() }
                            }
                            .buttonStyle(.plain)
                        }
                        NavigationLink { AboutView() } label: {
                            PanelRow(title: "Névjegy", systemImage: "info") { Chevron() }
                        }
                        .buttonStyle(.plain)
                    }

                    if let current = model.current {
                        PanelGroup {
                            Button { confirmLogout = current } label: {
                                PanelRow("Kijelentkezés", systemImage: "rectangle.portrait.and.arrow.right", tint: Color(palette.warning), destructive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Radír \(AppModel.appVersion)")
                        .font(.m(.footnote))
                        .foregroundStyle(Color(palette.secondaryText))
                }
                .padding(16)
            }
            .radirScreenBackground()
            .navigationTitle("Beállítások")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kész") { dismiss() }
                }
            }
            .sheet(isPresented: $addingAccount) {
                LoginView { addingAccount = false }
            }
            .confirmationDialog("Kijelentkezel?",
                                isPresented: Binding(get: { confirmLogout != nil }, set: { if !$0 { confirmLogout = nil } }),
                                titleVisibility: .visible, presenting: confirmLogout) { account in
                Button("Kijelentkezés: \(account.student.name)", role: .destructive) {
                    confirmLogout = nil
                    model.logout(account.id)
                }
                Button("Mégse", role: .cancel) { confirmLogout = nil }
            } message: { _ in
                Text("A fiók adatai törlődnek erről a telefonról.")
            }
            // Ha az utolsó fiókot jelentkeztük ki, a gyökérnézet a bejelentkezésre vált:
            // a lapot is be kell zárni, különben a régi képernyő marad felül.
            .onChange(of: model.current?.id) { _, id in
                if id == nil { dismiss() }
            }
        }
    }

    private var liveActivityBinding: Binding<Bool> {
        // bekapcsoláskor minden alkalommal megkérdezzük, mi kerül a szerverre (fiókonként)
        Binding(get: { model.liveActivity.isEnabled(for: model.current?.id) }, set: { on in
            if on {
                showConsent = true
            } else if let id = model.current?.id {
                model.liveActivity.setEnabled(false, for: id)
            }
        })
    }

    private func profile(_ account: Account) -> some View {
        VStack(spacing: 10) {
            AvatarView(name: account.student.name, size: 88)
            Text(account.student.name)
                .font(.title(24, relativeTo: .title))
                .foregroundStyle(Color(palette.text))
                .multilineTextAlignment(.center)
            Text(account.student.schoolName)
                .font(.m(.subheadline))
                .foregroundStyle(Color(palette.secondaryText))
                .multilineTextAlignment(.center)
            if account.isDemo {
                Text("Demó fiók")
                    .font(.m(.caption, .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(Color(palette.accent))
                    .background(Capsule().fill(Color(palette.accentSoft)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            AvatarView(name: account.student.name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.student.name).font(.m(.body, .semibold)).foregroundStyle(Color(palette.text))
                Text(account.needsRelogin ? "Újra be kell lépni" : LocalizedStringKey(account.student.schoolName))
                    .font(.m(.footnote, account.needsRelogin ? .semibold : .regular))
                    .foregroundStyle(account.needsRelogin ? Color(palette.warning) : Color(palette.secondaryText))
                    .lineLimit(1)
            }
            Spacer()
            if account.id == model.current?.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.m(.title3))
                    .foregroundStyle(Color(palette.accent))
                    .accessibilityLabel("Aktív fiók")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
