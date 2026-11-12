import RadirKit
import SwiftUI

/// Belépés KRÉTA fiókkal vagy demóval. Sheetben is használható új fiók hozzáadásához.
struct LoginView: View {
    var onDone: (() -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var request: LoginRequest?
    @State private var isWorking = false
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 104, height: 104)
                        .clipShape(.rect(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color(palette.accent).opacity(0.3), radius: 18, y: 10)
                        .rotationEffect(.degrees(-4))
                        .accessibilityHidden(true)
                    Text("Radír")
                        .font(.display(54))
                        .foregroundStyle(Color(palette.text))
                    Text("Jegyek, órarend, házik. Szépen, egy helyen.")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(palette.secondaryText))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)

                PanelGroup {
                    PanelRow("Jegyek és átlagok", subtitle: "Grafikon, jegykalkulátor, céltervező",
                             systemImage: "chart.line.uptrend.xyaxis", tint: Color(palette.gradeColor(5)!))
                    PanelRow("Órarend és Live Activity", subtitle: "A következő órád a zárolt képernyőn",
                             systemImage: "calendar.badge.clock")
                    PanelRow("Minden ingyenes", subtitle: "Nincs Plus, nincs reklám",
                             systemImage: "gift.fill", tint: Color(palette.warning))
                }

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(palette.warning))
                        .radirPanel()
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    errorText = nil
                    request = .make()
                } label: {
                    Group {
                        if isWorking { ProgressView().tint(.white) } else { Label("Belépés KRÉTA fiókkal", systemImage: "person.badge.key.fill") }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .radirProminentButton()
                .disabled(isWorking)

                Button {
                    model.startDemo()
                    onDone?()
                } label: {
                    Text("Kipróbálom demóval")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .radirSecondaryButton()
                .disabled(isWorking)

                Text("A belépés a KRÉTA saját oldalán történik.")
                    .font(.footnote)
                    .foregroundStyle(Color(palette.secondaryText))
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background { LoginBackground() }
        .sheet(item: $request) { req in
            KretaLoginSheet(request: req) { code in
                request = nil
                Task { await finish(code: code, request: req) }
            }
        }
    }

    private func finish(code: String, request: LoginRequest) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await model.completeLogin(code: code, request: request)
            onDone?()
        } catch KretaError.reloginRequired {
            errorText = "A belépés lejárt, próbáld újra."
        } catch {
            errorText = "Nem sikerült belépni. Ellenőrizd az internetet, és próbáld újra."
        }
    }
}

extension LoginRequest: @retroactive Identifiable {
    public var id: String { state }
}
