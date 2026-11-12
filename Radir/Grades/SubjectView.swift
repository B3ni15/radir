import RadirKit
import SwiftUI

struct SubjectView: View {
    let subject: Subject
    let book: GradeBook
    @Environment(\.palette) private var palette
    @State private var selected: Grade?

    var body: some View {
        let grades = book.grades(for: subject)
        let finals = book.finals(for: subject)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelGroup {
                    HStack(spacing: 14) {
                        Image(systemName: SubjectIcon.name(for: subject))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(palette.accent))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color(palette.accentSoft)))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subject.name).font(.title(24, relativeTo: .title))
                            if let teacher = grades.first?.teacher, !teacher.isEmpty {
                                Text(teacher).font(.subheadline).foregroundStyle(Color(palette.secondaryText))
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
                                    Text(finalTitle(g.kind)).font(.subheadline.weight(.semibold))
                                    GradeBubble(grade: g, size: 30)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
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
    }

    private func statBlock(_ title: LocalizedStringKey, value: Double?, filled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
            if let value { AverageBadge(value: value, filled: filled) } else { Text("–").font(.title3.weight(.bold)) }
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
                    Text(grade.subject.name).font(.subheadline).foregroundStyle(Color(palette.secondaryText))
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
                .font(.subheadline)
                .foregroundStyle(Color(palette.secondaryText))
                .multilineTextAlignment(.trailing)
        }
    }
}
