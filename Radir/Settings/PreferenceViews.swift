import RadirKit
import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var prefs = app.prefs
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Téma")
                    Picker("Téma", selection: $prefs.appearance) {
                        Text("Rendszer").tag(Preferences.Appearance.system)
                        Text("Világos").tag(Preferences.Appearance.light)
                        Text("Sötét").tag(Preferences.Appearance.dark)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Akcentusszín")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(Preferences.accents.indices, id: \.self) { i in
                            let a = Preferences.accents[i]
                            Button { withAnimation(.snappy) { prefs.accentIndex = i } } label: {
                                VStack(spacing: 6) {
                                    Circle().fill(Color(scheme == .dark ? a.dark : a.light))
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().strokeBorder(Color(palette.text), lineWidth: prefs.accentIndex == i ? 3 : 0).padding(-4))
                                    Text(a.name).font(.caption2).foregroundStyle(Color(palette.secondaryText)).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(prefs.accentIndex == i ? .isSelected : [])
                        }
                    }
                    .radirPanel()
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Részletes testreszabás")
                    VStack(spacing: 4) {
                        Toggle(isOn: $prefs.customEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Saját színek").font(.body.weight(.semibold))
                                Text("Bármilyen szín, mint a Firkában. A sötét és világos mód ilyenkor ugyanazokat a színeket használja.")
                                    .font(.footnote).foregroundStyle(Color(palette.secondaryText))
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        if prefs.customEnabled {
                            customColor("Akcentus", "accent", fallback: palette.accent)
                            customColor("Háttér", "background", fallback: palette.background)
                            customColor("Kártyák", "surface", fallback: palette.surface)
                            customColor("Szöveg", "text", fallback: palette.text)
                            Button("Saját színek törlése") { prefs.customColors = [:] }
                                .font(.subheadline.weight(.semibold)).padding(12)
                        }
                    }
                    .radirPanel()
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Jegyszínek")
                    VStack(spacing: 4) {
                        ForEach((1...5).reversed(), id: \.self) { v in
                            ColorPicker(selection: gradeBinding(v), supportsOpacity: false) {
                                HStack(spacing: 12) {
                                    Text("\(v)").font(.custom("Montserrat-Bold", size: 17))
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Color(palette.gradeColor(v)!).opacity(0.25)))
                                    Text(["", "Elégtelen", "Elégséges", "Közepes", "Jó", "Jeles"][v])
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                        }
                        if prefs.gradeColors != nil {
                            Button("Alap jegyszínek visszaállítása") { prefs.gradeColors = nil }
                                .font(.subheadline.weight(.semibold)).padding(12)
                        }
                    }
                    .radirPanel()
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Megjelenés")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func customColor(_ title: LocalizedStringKey, _ key: String, fallback: ARGB) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(app.prefs.customColors[key].map(ARGB.init) ?? fallback) },
                                              set: { app.prefs.customColors[key] = ARGB(color: $0).value }),
                    supportsOpacity: false)
            .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func gradeBinding(_ v: Int) -> Binding<Color> {
        Binding(get: { Color(palette.gradeColor(v)!) }, set: { color in
            var colors = app.prefs.gradeColors ?? Palette.defaultGrades.map(\.value)
            colors[v - 1] = ARGB(color: color).value
            app.prefs.gradeColors = colors
        })
    }
}

extension ARGB {
    init(color: Color) {
        let c = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ x: CGFloat) -> UInt32 { UInt32((min(max(x, 0), 1) * 255).rounded()) }
        self.init(0xFF00_0000 | byte(r) << 16 | byte(g) << 8 | byte(b))
    }
}

struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var prefs = app.prefs
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PanelGroup(title: "Indítás") {
                    PanelRow(title: "Kezdőoldal", systemImage: "app.badge") {
                        Picker("Kezdőoldal", selection: $prefs.startTab) {
                            Text("Kezdőlap").tag(AppTab.home)
                            Text("Jegyek").tag(AppTab.grades)
                            Text("Órarend").tag(AppTab.timetable)
                            Text("Füzet").tag(AppTab.notes)
                            Text("Hiányzások").tag(AppTab.absences)
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        PanelRow("Üdvözlő üzenet", subtitle: "Üresen a napszaknak megfelelő köszöntés. A %s helyére a keresztneved kerül.", systemImage: "hand.wave")
                        TextField("Szia, %s!", text: $prefs.welcomeMessage)
                            .textFieldStyle(.roundedBorder)
                            .padding([.horizontal, .bottom], 14)
                    }
                }

                PanelGroup(title: "Jegyek") {
                    VStack(alignment: .leading, spacing: 6) {
                        PanelRow(title: "Kerekítés", subtitle: "Ennyitől kerekít felfelé a jegyszín (pl. 3,50 → 4).", systemImage: "arrow.up.right") {
                            Text(prefs.roundingThreshold, format: .number.precision(.fractionLength(1))).font(.body.weight(.semibold).monospacedDigit())
                        }
                        Slider(value: $prefs.roundingThreshold, in: 0.1...0.9, step: 0.1).padding([.horizontal, .bottom], 14)
                    }
                }

                PanelGroup(title: "Órarend") {
                    PanelRow(title: "Csengetési eltolás", subtitle: "Ha az iskola órája siet vagy késik.", systemImage: "bell.badge") {
                        Stepper(value: $prefs.bellDelay, in: -300...300, step: 15) {
                            Text(delayText(prefs.bellDelay)).font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        .fixedSize()
                    }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Általános")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delayText(_ s: Int) -> String {
        s == 0 ? String(localized: "nincs") : "\(s > 0 ? "+" : "−")\(abs(s) / 60):\(String(format: "%02d", abs(s) % 60))"
    }
}

/// Tantárgyak és tanárok átnevezése; csak ezen a telefonon, ennél a fióknál.
struct RenameSettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var subjects: [Subject] = []
    @State private var teachers: [String] = []
    @State private var draft = Renaming()

    var body: some View {
        List {
            Section("Tantárgyak") {
                ForEach(subjects) { s in
                    TextField(s.name, text: Binding(get: { draft.subjects[s.id] ?? "" }, set: { draft.subjects[s.id] = $0.isEmpty ? nil : $0 }))
                }
                .listRowBackground(Color(palette.surface))
            }
            Section("Tanárok") {
                ForEach(teachers, id: \.self) { t in
                    TextField(t, text: Binding(get: { draft.teachers[t] ?? "" }, set: { draft.teachers[t] = $0.isEmpty ? nil : $0 }))
                }
                .listRowBackground(Color(palette.surface))
            }
        }
        .radirScreenBackground()
        .navigationTitle("Átnevezés")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: collect)
        .onDisappear {
            guard draft != app.renaming else { return }
            app.notebook.update { $0.renaming = draft }
            app.reloadData()
        }
    }

    /// Az eredeti nevek: a tárolt (átnevezés előtti) adatokból.
    private func collect() {
        draft = app.renaming
        guard let account = app.current else { return }
        let book = account.isDemo ? Demo.gradeBook() : app.cache.load(GradeBook.self, as: "grades", for: account.id)
        let week = SchoolWeek(containing: .now)
        let key = "timetable-\(week.start.formatted(.iso8601.year().month().day()))"
        let lessons = account.isDemo ? Demo.lessons(for: week) : (app.cache.load([Lesson].self, as: key, for: account.id) ?? [])
        var seen: [String: Subject] = [:]
        for s in (book?.grades.map(\.subject) ?? []) + lessons.map(\.subject) where !s.id.isEmpty { seen[s.id] = seen[s.id] ?? s }
        let hu = Locale(identifier: "hu_HU")
        subjects = seen.values.sorted { $0.name.compare($1.name, locale: hu) == .orderedAscending }
        let names = Set((book?.grades.map(\.teacher) ?? []) + lessons.map(\.teacher)).filter { !$0.isEmpty }
        teachers = names.sorted { $0.compare($1, locale: hu) == .orderedAscending }
    }
}
