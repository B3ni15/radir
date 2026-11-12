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
                            Task { await model.liveActivity.sync(app: model) }
                        } cancel: { showConsent = false }
                    }

                    PanelGroup(title: "Egyéb") {
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
                        .font(.footnote)
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
                    Task { await model.logout(account.id) }
                }
                Button("Mégse", role: .cancel) { confirmLogout = nil }
            } message: { _ in
                Text("A fiók adatai törlődnek erről a telefonról.")
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
                .shadow(color: Color(palette.accent).opacity(0.35), radius: 16, y: 8)
            Text(account.student.name)
                .font(.title(24, relativeTo: .title))
                .foregroundStyle(Color(palette.text))
                .multilineTextAlignment(.center)
            Text(account.student.schoolName)
                .font(.subheadline)
                .foregroundStyle(Color(palette.secondaryText))
                .multilineTextAlignment(.center)
            if account.isDemo {
                Text("Demó fiók")
                    .font(.caption.weight(.bold))
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
                Text(account.student.name).font(.body.weight(.semibold)).foregroundStyle(Color(palette.text))
                Text(account.needsRelogin ? "Újra be kell lépni" : LocalizedStringKey(account.student.schoolName))
                    .font(.footnote.weight(account.needsRelogin ? .semibold : .regular))
                    .foregroundStyle(account.needsRelogin ? Color(palette.warning) : Color(palette.secondaryText))
                    .lineLimit(1)
            }
            Spacer()
            if account.id == model.current?.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(palette.accent))
                    .accessibilityLabel("Aktív fiók")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
