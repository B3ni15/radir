import RadirKit
import SwiftUI
import WebKit

/// Az e-KRÉTA saját belépő oldala. A redirectet elkapjuk, így a jelszó soha nem jár nálunk.
struct KretaLoginSheet: View {
    let request: LoginRequest
    var prefill: LoginPrefill?
    /// Ha nem tölt be a belépő oldal (pl. külföldről nem érhető el), innen is indulhat a demó.
    var onDemo: (() -> Void)?
    let onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadedOnce = false
    @State private var timedOut = false
    @State private var failed = false
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            ZStack {
                KretaWebLogin(request: request, prefill: prefill, reloadToken: reloadToken, onCode: onCode, onLoading: { loading in
                    isLoading = loading
                    if !loading { loadedOnce = true }
                }, onFailed: { failed = true })
                if failed || (timedOut && !loadedOnce) {
                    ContentUnavailableView {
                        Label("Nem töltött be a bejelentkező oldal", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Ellenőrizd az internetet. Az e-KRÉTA belépés külföldről nem mindig érhető el.")
                    } actions: {
                        Button("Újra") {
                            timedOut = false
                            failed = false
                            loadedOnce = false
                            reloadToken += 1
                        }
                        if let onDemo {
                            Button("Kipróbálom demóval", action: onDemo)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .background(.background)
                } else if isLoading && !loadedOnce {
                    ProgressView()
                }
            }
            .navigationTitle("Bejelentkezés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Mégse") { dismiss() }
                }
            }
            .task(id: reloadToken) {
                try? await Task.sleep(for: .seconds(30))
                if !loadedOnce { timedOut = true }
            }
        }
    }
}

/// A telefonon tárolt adatok, amikkel a KRÉTA belépő oldala előre kitölthető. A jelszó nincs köztük.
struct LoginPrefill: Equatable {
    let userName: String
    let instituteCode: String
    let schoolName: String

    /// Kitölti a felhasználónevet és az iskolát, a fókusz a jelszó mezőre kerül.
    var script: String {
        func js(_ s: String) -> String {
            String(data: try! JSONEncoder().encode(s), encoding: .utf8)!
        }
        return """
        (function() {
          function set(id, v) { var e = document.getElementById(id); if (!e) return;
            e.value = v; e.dispatchEvent(new Event('input', {bubbles: true})); e.dispatchEvent(new Event('change', {bubbles: true})); }
          set('UserName', \(js(userName)));
          set('InstituteCode', \(js(instituteCode)));
          set('instituteSelector', \(js(schoolName)));
          var p = document.getElementById('Password'); if (p) p.focus();
        })();
        """
    }
}

struct KretaWebLogin: UIViewRepresentable {
    let request: LoginRequest
    var prefill: LoginPrefill?
    let reloadToken: Int
    let onCode: (String) -> Void
    let onLoading: (Bool) -> Void
    /// Hálózati hiba, vagy hibaoldal (4xx/5xx) jött a belépő oldal helyett.
    var onFailed: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        if let prefill {
            // csak a KRÉTA belépő oldalán fut le
            config.userContentController.addUserScript(WKUserScript(
                source: "if (location.host === 'idp.e-kreta.hu') {\(prefill.script)}",
                injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: request.authorizeURL))
        context.coordinator.loadedToken = reloadToken
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedToken != reloadToken {
            context.coordinator.loadedToken = reloadToken
            view.load(URLRequest(url: request.authorizeURL))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: KretaWebLogin
        var loadedToken = 0
        private var delivered = false

        init(_ parent: KretaWebLogin) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url, let code = parent.request.code(from: url) else { return .allow }
            if !delivered {
                delivered = true
                parent.onCode(code)
            }
            return .cancel
        }

        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            // külföldről a KRÉTA hibaoldalt adhat (pl. 403): azt ne mutassuk belépő oldalként
            if response.isForMainFrame, let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
                parent.onFailed()
            }
            return .allow
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failed(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }

        private func failed(_ error: Error) {
            let e = error as NSError
            // a saját redirect-elkapásunk (cancel) és a félbeszakított betöltés nem hiba
            if delivered || (e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled) || (e.domain == "WebKitErrorDomain" && e.code == 102) { return }
            parent.onLoading(false)
            parent.onFailed()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { parent.onLoading(true) }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.onLoading(false) }
    }
}
