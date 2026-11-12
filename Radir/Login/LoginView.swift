import RadirKit
import SwiftUI

/// Belépés KRÉTA fiókkal, a Firka kezdőképernyője mintájára: lapozható bemutató, alatta a belépés.
/// A demó rejtett (mint a Firkában): a logóra tízszer koppintva indul. Az App Review jegyzetben le van írva.
/// Sheetben is használható új fiók hozzáadásához.
struct LoginView: View {
    var onDone: (() -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var request: LoginRequest?
    @State private var isWorking = false
    @State private var errorText: LocalizedStringKey?
    @State private var page = 0
    @State private var logoTaps = 0

    private static let slides: [(title: LocalizedStringKey, text: LocalizedStringKey, image: String)] = [
        ("Minden, ami ma számít", "A mostani és a következő órád, a házik, a dolgozatok és az új jegyeid egy helyen.", "Showcase1"),
        ("Látod, merre tart az átlagod", "Grafikon, osztályátlag és jegyeloszlás. Jegykalkulátorral és céltervezővel.", "Showcase2"),
        ("Az órarended, élőben", "Szünetek, helyettesítések, elmaradt órák. A következő órád a zárolt képernyőn is.", "Showcase3"),
        ("Év végén jön a bizonyítvány", "Egy kis összefoglaló az évedről: jegyek, kedvenc óra, és hogy milyen diák voltál.", "Showcase4"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                Text("Radír").font(.custom("Montserrat-Bold", size: 18, relativeTo: .headline))
            }
            .padding(.vertical, 6)
            .contentShape(.rect)
            .onTapGesture {
                logoTaps += 1
                if logoTaps >= 10 {
                    logoTaps = 0
                    model.startDemo()
                    onDone?()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            TabView(selection: $page) {
                ForEach(Self.slides.indices, id: \.self) { i in
                    slide(Self.slides[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(Color(palette.background).ignoresSafeArea())
        .foregroundStyle(Color(palette.text))
        // automatikus lapozás 6 mp-enként; kézi lapozás után újraindul
        .task(id: page) {
            guard !reduceMotion, (try? await Task.sleep(for: .seconds(6))) != nil else { return }
            withAnimation(.smooth) { page = (page + 1) % Self.slides.count }
        }
        .sheet(item: $request) { req in
            KretaLoginSheet(request: req) { code in
                request = nil
                Task { await finish(code: code, request: req) }
            }
        }
    }

    private func slide(_ s: (title: LocalizedStringKey, text: LocalizedStringKey, image: String)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(s.title).font(.m(.title2)).fixedSize(horizontal: false, vertical: true)
                Text(s.text)
                    .font(.m(.body))
                    .foregroundStyle(Color(palette.secondaryText))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            // teljes szélességben, alul levágva (a belépés sáv elhalványítja)
            GeometryReader { g in
                Image(s.image)
                    .resizable()
                    .frame(width: g.size.width, height: g.size.width * 2868 / 1320)
                    .clipShape(.rect(cornerRadius: 34, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Color(palette.separator), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(Self.slides.indices, id: \.self) { i in
                    Capsule()
                        .fill(Color(i == page ? palette.accent : palette.separator))
                        .frame(width: i == page ? 20 : 7, height: 7)
                }
            }
            .animation(.smooth, value: page)
            .accessibilityHidden(true)

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.m(.subheadline, .semibold))
                    .foregroundStyle(Color(palette.warning))
            }

            Button {
                errorText = nil
                request = .make()
            } label: {
                Group {
                    if isWorking { ProgressView().tint(.white) } else { Label("Belépés KRÉTA fiókkal", systemImage: "person.badge.key.fill") }
                }
                .font(.m(.body, .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .radirProminentButton()
            .controlSize(.large)
            .disabled(isWorking)

            Text("Ingyenes, reklám nélkül. A belépés a KRÉTA saját oldalán történik.")
                .font(.m(.footnote))
                .foregroundStyle(Color(palette.secondaryText))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 48)
        .padding(.bottom, 8)
        .background {
            LinearGradient(stops: [.init(color: Color(palette.background).opacity(0), location: 0),
                                   .init(color: Color(palette.background), location: 0.3)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
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
