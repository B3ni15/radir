import RadirKit
import SwiftUI

/// Füzet: házi feladatok, számonkérések, beírások, saját jegyzetek és teendők.
struct NotebookView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var homeworkDetail: Homework?
    @State private var examDetail: Exam?
    @State private var noteDetail: SchoolNote?
    @State private var editing: Notebook.Note?
    @State private var newTodo = ""
    @State private var showDoneHomework = false

    var body: some View {
        let today = Calendar.school.startOfDay(for: .now)
        let nb = app.notebook.notebook
        let homework = (app.school.homework ?? []).filter { $0.deadline >= today }.sorted { $0.deadline < $1.deadline }
        let open = homework.filter { !nb.doneHomework.contains($0.id) }
        let done = homework.filter { nb.doneHomework.contains($0.id) }
        let exams = (app.school.exams ?? []).filter { $0.date >= today }.sorted { $0.date < $1.date }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PanelGroup(title: "Házi feladatok") {
                    if open.isEmpty {
                        PanelRow("Nincs leadandó házid", systemImage: "checkmark.circle.fill", tint: Color(palette.gradeColor(5)!))
                    }
                    ForEach(open) { h in
                        Button { homeworkDetail = h } label: { HomeworkRow(homework: h) }.buttonStyle(.plain)
                    }
                    if !done.isEmpty {
                        Button { withAnimation(.snappy) { showDoneHomework.toggle() } } label: {
                            PanelRow(title: showDoneHomework ? "Kész házik elrejtése" : "\(done.count) kész házi",
                                     systemImage: "checkmark.circle") { Chevron().rotationEffect(.degrees(showDoneHomework ? 90 : 0)) }
                        }
                        .buttonStyle(.plain)
                        if showDoneHomework {
                            ForEach(done) { h in
                                Button { homeworkDetail = h } label: { HomeworkRow(homework: h, isDone: true) }.buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !exams.isEmpty {
                    PanelGroup(title: "Számonkérések") {
                        ForEach(exams) { e in
                            Button { examDetail = e } label: { ExamRow(exam: e) }.buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Jegyzeteim")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        Button { editing = Notebook.Note(title: "", text: "") } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus").font(.title2.weight(.semibold))
                                Text("Új jegyzet").font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(Color(palette.accent))
                            .frame(maxWidth: .infinity, minHeight: 110)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color(palette.accent).opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        }
                        .buttonStyle(.plain)
                        ForEach(nb.notes.sorted { $0.updated > $1.updated }) { note in
                            Button { editing = note } label: { noteCard(note) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Törlés", systemImage: "trash", role: .destructive) {
                                        app.notebook.update { $0.notes.removeAll { $0.id == note.id } }
                                    }
                                }
                        }
                    }
                }

                PanelGroup(title: "Teendők") {
                    ForEach(nb.todos) { todo in
                        HStack(spacing: 12) {
                            Button {
                                app.notebook.update { nb in
                                    if let i = nb.todos.firstIndex(where: { $0.id == todo.id }) { nb.todos[i].isDone.toggle() }
                                }
                            } label: {
                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(Color(todo.isDone ? palette.gradeColor(5)! : palette.secondaryText))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(todo.isDone ? "Kész" : "Nincs kész")
                            Text(todo.title).strikethrough(todo.isDone).foregroundStyle(Color(todo.isDone ? palette.secondaryText : palette.text))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contextMenu {
                            Button("Törlés", systemImage: "trash", role: .destructive) {
                                app.notebook.update { $0.todos.removeAll { $0.id == todo.id } }
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color(palette.accent))
                        TextField("Új teendő", text: $newTodo)
                            .submitLabel(.done)
                            .onSubmit(addTodo)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                if let notes = app.school.notes, !notes.isEmpty {
                    PanelGroup(title: "Beírások") {
                        ForEach(notes.sorted { $0.date > $1.date }) { n in
                            Button { noteDetail = n } label: { SchoolNoteRow(note: n) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .refreshable { await app.school.load(app) }
        .task(id: app.current?.id) {
            app.notebook.open(app)
            await app.school.load(app)
        }
        .sheet(item: $homeworkDetail) { HomeworkDetailSheet(homework: $0) }
        .sheet(item: $examDetail) { ExamDetailSheet(exam: $0) }
        .sheet(item: $noteDetail) { SchoolNoteDetailSheet(note: $0) }
        .sheet(item: $editing) { NoteEditor(note: $0) }
    }

    private func addTodo() {
        let title = newTodo.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        app.notebook.update { $0.todos.append(Notebook.Todo(title: title)) }
        newTodo = ""
    }

    private func noteCard(_ note: Notebook.Note) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !note.title.isEmpty { Text(note.title).font(.subheadline.weight(.bold)).lineLimit(1) }
            Text(note.text).font(.footnote).foregroundStyle(Color(palette.secondaryText)).lineLimit(4)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(palette.text))
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(14)
        .background(Color(palette.surface), in: .rect(cornerRadius: 18, style: .continuous))
    }
}

/// Saját jegyzet szerkesztése; mentéskor a füzetbe kerül.
struct NoteEditor: View {
    @State var note: Notebook.Note
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Cím", text: $note.title).font(.title(22, relativeTo: .title2))
                TextEditor(text: $note.text).scrollContentBackground(.hidden)
            }
            .padding(20)
            .radirScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Mégse") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mentés") {
                        var n = note
                        n.updated = .now
                        app.notebook.update { nb in
                            if let i = nb.notes.firstIndex(where: { $0.id == n.id }) { nb.notes[i] = n } else { nb.notes.append(n) }
                        }
                        dismiss()
                    }
                    .disabled(note.title.trimmingCharacters(in: .whitespaces).isEmpty && note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
