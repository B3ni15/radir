import RadirKit
import SwiftUI

/// Jegykalkulátor: elképzelt jegyekkel számolja az új átlagot.
struct CalculatorView: View {
    let subject: Subject
    let grades: [Grade]
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var ghosts: [Grade] = []
    @State private var value = 5
    @State private var weight = 100.0

    var body: some View {
        let before = Averages.weighted(grades)
        let after = Averages.weighted(grades + ghosts)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        avgBlock("Most", before)
                        Image(systemName: "arrow.right").foregroundStyle(Color(palette.secondaryText))
                        avgBlock("Új átlag", after)
                        if let b = before, let a = after, !ghosts.isEmpty { TrendLabel(delta: a - b) }
                    }
                    .frame(maxWidth: .infinity)
                    .radirPanel()

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Új jegy")
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ForEach((1...5).reversed(), id: \.self) { v in
                                    let c = Color(palette.gradeColor(v)!)
                                    Button { value = v } label: {
                                        Text("\(v)")
                                            .font(.custom("Montserrat-Bold", size: 20))
                                            .foregroundStyle(value == v ? .white : c.gradeInk(scheme))
                                            .frame(width: 48, height: 48)
                                            .background(Circle().fill(value == v ? c : c.opacity(0.2)))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(value == v ? .isSelected : [])
                                }
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Súly: \(Int(weight))%").font(.subheadline.weight(.semibold))
                                Slider(value: $weight, in: 50...400, step: 50)
                            }
                            Button {
                                withAnimation(.snappy) { ghosts.append(.ghost(value: value, weight: Int(weight), subject: subject)) }
                            } label: {
                                Label("Hozzáadás", systemImage: "plus").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
                            }
                            .radirProminentButton()
                            .disabled(ghosts.count >= 50)
                        }
                        .radirPanel()
                    }

                    if !ghosts.isEmpty {
                        PanelGroup(title: "Elképzelt jegyek") {
                            ForEach(ghosts) { g in
                                HStack {
                                    GradeBubble(grade: g, size: 36)
                                    Text("\(g.weight)%").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button("Törlés", systemImage: "xmark.circle.fill") {
                                        withAnimation(.snappy) { ghosts.removeAll { $0.id == g.id } }
                                    }
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(Color(palette.secondaryText))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .radirScreenBackground()
            .navigationTitle("Jegykalkulátor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Kész") { dismiss() } }
                if !ghosts.isEmpty {
                    ToolbarItem(placement: .cancellationAction) { Button("Ürítés") { withAnimation { ghosts = [] } } }
                }
            }
        }
    }

    private func avgBlock(_ title: LocalizedStringKey, _ v: Double?) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
            if let v { AverageBadge(value: v) } else { Text("–").font(.title3.weight(.bold)) }
        }
    }
}

/// Céltervező: milyen jegyek kellenek a kitűzött átlaghoz.
struct GoalPlannerView: View {
    let subject: Subject
    let grades: [Grade]
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var goal = 4.0

    var body: some View {
        let result = GoalPlanner.solve(goal: goal, grades: grades)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        Text("Célátlag").font(.footnote.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
                        Text(goal, format: .number.precision(.fractionLength(2)))
                            .font(.custom("Montserrat-Bold", size: 44, relativeTo: .largeTitle))
                            .foregroundStyle(Color(palette.gradeColor(forAverage: goal)).gradeInk(.light))
                            .contentTransition(.numericText())
                        Slider(value: $goal, in: 2...5, step: 0.05)
                        if let avg = Averages.weighted(grades) {
                            Text("Most: \(avg, format: .number.precision(.fractionLength(2)))").font(.subheadline).foregroundStyle(Color(palette.secondaryText))
                        }
                    }
                    .radirPanel()

                    switch result {
                    case .reached:
                        PanelGroup { PanelRow("Már elérted!", subtitle: "Az átlagod most is legalább ennyi.", systemImage: "checkmark.seal.fill", tint: Color(palette.gradeColor(5)!)) }
                    case .unsolvable:
                        PanelGroup { PanelRow("Ez a cél nem érhető el", subtitle: "Ennyi jeggyel már nem lehet ekkora az átlag.", systemImage: "xmark.octagon.fill", tint: Color(palette.warning)) }
                    case .unreachable:
                        PanelGroup { PanelRow("Túl sok jegy kellene", subtitle: "Több mint 20 jó jegy kellene hozzá. Próbálj kisebb célt.", systemImage: "exclamationmark.triangle.fill", tint: Color(palette.gradeColor(2)!)) }
                    case .plans(let rec, let fastest, let others):
                        PanelGroup(title: "Ajánlott út") { planRow(rec) }
                        if let fastest { PanelGroup(title: "Leggyorsabb út") { planRow(fastest) } }
                        if !others.isEmpty {
                            PanelGroup(title: "Más utak") { ForEach(others.prefix(4), id: \.self) { planRow($0) } }
                        }
                    }
                }
                .padding(16)
                .animation(.snappy, value: goal)
            }
            .radirScreenBackground()
            .navigationTitle("Céltervező")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Mégse") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mentés") {
                        app.notebook.update { $0.goals[subject.id] = goal }
                        dismiss()
                    }
                }
            }
            .onAppear {
                app.notebook.open(app)
                if let saved = app.notebook.notebook.goals[subject.id] { goal = saved }
                else if let avg = Averages.weighted(grades) { goal = min(5, (avg * 20).rounded(.up) / 20 + 0.25) }
            }
        }
    }

    private func planRow(_ plan: GoalPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(plan.grades.count) jegy kell").font(.subheadline.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(plan.grades.enumerated()), id: \.offset) { _, v in
                        GradeBubble(grade: .ghost(value: v, weight: 100, subject: subject), size: 34)
                    }
                }
            }
        }
        .padding(16)
    }
}
