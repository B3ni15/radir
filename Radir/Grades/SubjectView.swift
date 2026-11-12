import RadirKit
import SwiftUI

struct SubjectView: View {
    let subject: Subject
    let book: GradeBook
    @Environment(\.palette) private var palette
    @State private var selected: Grade?
    @State private var showCalculator = false
    @State private var showGoal = false
    @Environment(AppModel.self) private var app

    var body: some View {
        let grades = book.grades(for: subject)
        let finals = book.finals(for: subject)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelGroup {
                    HStack(spacing: 14) {
                        Image(systemName: SubjectIcon.name(for: subject))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(palette.text).opacity(0.8))
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subject.name).font(.title(24, relativeTo: .title))
                            if let teacher = grades.first?.teacher, !teacher.isEmpty {
                                Text(teacher).font(.m(.subheadline)).foregroundStyle(Color(palette.secondaryText))
                            }
                        }
                    }
                    .padding(16)
                    HStack {
                        statBlock("Átlagod", value: Averages.weighted(grades), filled: false)
                        Spacer()
                        statBlock("Osztályátlag", value: book.classAverage(for: subject), filled: true)
                    }
                    .padding(16)
                    if !finals.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(finals) { g in
                                HStack(spacing: 6) {
                                    Text(finalTitle(g.kind)).font(.m(.subheadline, .semibold))
                                    GradeBubble(grade: g, size: 30)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                }

                PanelGroup {
                    Button { showCalculator = true } label: {
                        PanelRow("Jegykalkulátor", subtitle: "Mi lenne, ha kapnék egy…", systemImage: "plus.forwardslash.minus") { Chevron() }
                    }
                    .buttonStyle(.plain)
                    Button { showGoal = true } label: {
                        if let goal = app.notebook.notebook.goals[subject.id] {
                            PanelRow(title: "Cél: \(goal.formatted(.number.precision(.fractionLength(2))))",
                                     subtitle: (Averages.weighted(grades) ?? 0) >= goal ? "Elérted! 🎉" : "Koppints, és megnézheted, mi kell hozzá.",
                                     systemImage: "flag.checkered") { Chevron() }
                        } else {
                            PanelRow("Céltervező", subtitle: "Milyen jegyek kellenek a kitűzött átlaghoz?", systemImage: "flag.checkered") { Chevron() }
                        }
                    }
                    .buttonStyle(.plain)
                }

                PanelGroup(title: "Grafikon") {
                    AverageChart(points: Averages.timeline(grades, gapDays: 5), classAverage: book.classAverage(for: subject))
                    GradeDistribution(grades: grades)
                }

                PanelGroup(title: "Jegyek") {
                    ForEach(grades) { g in
                        Button { selected = g } label: { GradeRow(grade: g) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { GradeDetailSheet(grade: $0) }
        .sheet(isPresented: $showCalculator) { CalculatorView(subject: subject, grades: grades) }
        .sheet(isPresented: $showGoal) { GoalPlannerView(subject: subject, grades: grades) }
        .onAppear { app.notebook.open(app) }
    }

    private func statBlock(_ title: LocalizedStringKey, value: Double?, filled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.m(.footnote, .semibold)).foregroundStyle(Color(palette.secondaryText))
            if let value { AverageBadge(value: value, filled: filled) } else { Text("–").font(.m(.title3, .bold)) }
        }
    }

    private func finalTitle(_ kind: GradeKind) -> LocalizedStringKey {
        switch kind {
        case .halfYear: "Félév"
        case .endYear: "Év vége"
        case .firstQ: "I. negyedév"
        case .secondQ: "II. negyedév"
        case .thirdQ: "III. negyedév"
        case .fourthQ: "IV. negyedév"
        case .levelExam: "Osztályozó vizsga"
        case .midYear, .unknown: ""
        }
    }
}

struct GradeDetailSheet: View {
    let grade: Grade
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    GradeBubble(grade: grade, size: 76)
                    Text(grade.valueName.isEmpty ? String(grade.value) : grade.valueName)
                        .font(.title(26, relativeTo: .title))
                    Text(grade.subject.name).font(.m(.subheadline)).foregroundStyle(Color(palette.secondaryText))
                }
                .padding(.top, 24)
                PanelGroup {
                    if !grade.topic.isEmpty { detail("Téma", grade.topic, "text.alignleft") }
                    if !grade.mode.isEmpty { detail("Mód", grade.mode, "pencil.and.list.clipboard") }
                    detail("Súly", "\(grade.weight)%", "scalemass")
                    detail("Dátum", grade.date.formatted(date: .long, time: .omitted), "calendar")
                    if grade.writeDate != grade.date {
                        detail("Beírva", grade.writeDate.formatted(date: .abbreviated, time: .shortened), "square.and.pencil")
                    }
                    if !grade.teacher.isEmpty { detail("Tanár", grade.teacher, "person") }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func detail(_ title: LocalizedStringKey, _ value: String, _ icon: String) -> some View {
        PanelRow(title: title, systemImage: icon) {
            Text(value)
                .font(.m(.subheadline))
                .foregroundStyle(Color(palette.secondaryText))
                .multilineTextAlignment(.trailing)
        }
    }
}
