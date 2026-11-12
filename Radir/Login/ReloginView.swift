import RadirKit
import SwiftUI

/// Teljes képernyő, ha a KRÉTA belépés lejárt: a felhasználónév és az iskola ki van töltve, csak a jelszó kell.
struct ReloginView: View {
    let account: Account
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var request = LoginRequest.make()
    @State private var isWorking = false
    @State private var errorText: LocalizedStringKey?
    @State private var confirmLogout = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AvatarView(name: account.student.name, size: 64)
                Text("Jelentkezz be újra").font(.title(24, relativeTo: .title))
                Text("\(account.student.name) · \(account.student.schoolName)")
                    .font(.subheadline)
                    .foregroundStyle(Color(palette.secondaryText))
                    .multilineTextAlignment(.center)
                Text("A felhasználónevet és az iskolát kitöltöttük, csak a jelszavad kell.")
                    .font(.footnote)
                    .foregroundStyle(Color(palette.secondaryText))
                    .multilineTextAlignment(.center)
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(palette.warning))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            ZStack {
                KretaWebLogin(request: request, prefill: prefill, reloadToken: 0, onCode: finish) { _ in }
                    .id(request.state)
                if isWorking { ProgressView().controlSize(.large) }
            }
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 12)

            HStack {
                if app.accounts.count > 1 {
                    Menu("Másik fiók") {
                        ForEach(app.accounts.filter { $0.id != account.id }) { other in
                            Button(other.student.name) { app.select(other.id) }
                        }
                    }
                }
                Spacer()
                Button("Kijelentkezés", role: .destructive) { confirmLogout = true }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background { LoginBackground() }
        .confirmationDialog("Kijelentkezel?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Kijelentkezés: \(account.student.name)", role: .destructive) {
                Task { await app.logout(account.id) }
            }
        } message: {
            Text("A fiók adatai törlődnek erről a telefonról.")
        }
    }

    private var prefill: LoginPrefill {
        LoginPrefill(userName: account.userName, instituteCode: account.instituteCode, schoolName: account.student.schoolName)
    }

    private func finish(_ code: String) {
        let req = request
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                try await app.completeLogin(code: code, request: req)
            } catch {
                errorText = "Nem sikerült belépni, próbáld újra."
                request = .make()
            }
        }
    }
}
