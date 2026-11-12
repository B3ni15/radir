import RadirKit
import SwiftUI

enum AppTab: Hashable {
    case home, grades, timetable, notes, absences
}

struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = app
        TabView(selection: $router.tab) {
            Tab("Kezdőlap", systemImage: "house.fill", value: .home) {
                HomeView()
            }
            Tab("Jegyek", systemImage: "bookmark.fill", value: .grades) {
                TabScreen(title: "Tantárgyak") { GradesView() }
            }
            Tab("Órarend", systemImage: "calendar", value: .timetable) {
                TabScreen(title: "Órarend") { TimetableView() }
            }
            Tab("Füzet", systemImage: "book.closed.fill", value: .notes) {
                TabScreen(title: "Füzet") { NotebookView() }
            }
            Tab("Hiányzások", systemImage: "timer", value: .absences) {
                TabScreen(title: "Hiányzások") { AbsencesView() }
            }
        }
        // amikor visszajössz az appba, mindig friss órarend és jegyek kellenek (a változás fontos); ez el is mentődik
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                async let t: Void = app.timetable.loadAround(app, week: SchoolWeek(containing: .now))
                async let g: Void = app.grades.load(app)
                _ = await (t, g)
                await app.liveActivity.sync(app: app)
            }
        }
        // előtérben félpercenként frissíti a Live Activityt; háttérben a szerver teszi ezt
        .task(id: app.current?.id) {
            while !Task.isCancelled {
                let week = SchoolWeek(containing: .now)
                if !app.timetable.hasLoaded(week) { await app.timetable.load(app, week: week) }
                await app.liveActivity.sync(app: app)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

/// Egy fül: saját navigáció, nagy cím és a profil gomb a beállításokhoz.
struct TabScreen<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .toolbar { AvatarToolbarItem(name: model.current?.student.name ?? "") { showSettings = true } }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

/// A profil gomb a jobb felső sarokban, mint a kezdőlapon: iOS 26-on üveghátter nélkül, hogy ne nyomja össze.
struct AvatarToolbarItem: ToolbarContent {
    let name: String
    let action: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            item.sharedBackgroundVisibility(.hidden)
        } else {
            item
        }
    }

    private var item: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: action) { AvatarView(name: name, size: 38) }
                .buttonStyle(.plain)
                .accessibilityLabel("Beállítások")
        }
    }
}
