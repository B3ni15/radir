import SwiftUI

@main
struct RadirApp: App {
    @State private var model = AppModel()
    @AppStorage("onboardingDone") private var onboardingDone = false

    init() { RadirFont.register() }

    var body: some Scene {
        WindowGroup {
            Group {
                if let current = model.current {
                    if current.needsRelogin {
                        ReloginView(account: current)
                    } else {
                        MainTabView()
                            .fullScreenCover(isPresented: Binding(get: { !onboardingDone }, set: { if !$0 { onboardingDone = true } })) {
                                OnboardingView { onboardingDone = true }
                                    .environment(model)
                                    .radirTheme(model.prefs)
                            }
                    }
                } else {
                    LoginView()
                }
            }
            .environment(model)
            .radirTheme(model.prefs)
        }
    }
}
