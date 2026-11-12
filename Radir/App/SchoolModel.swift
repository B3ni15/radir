import Foundation
import Observation
import RadirKit

/// Hiányzások, házi feladatok, számonkérések és beírások a kiválasztott fiókhoz: tárolt adat azonnal, aztán frissítés.
@Observable
final class SchoolModel {
    private(set) var absences: [Absence]?
    private(set) var homework: [Homework]?
    private(set) var exams: [Exam]?
    private(set) var notes: [SchoolNote]?
    private(set) var wall: [WallItem]?
    private(set) var isLoading = false
    private var loadedCache = false

    func load(_ app: AppModel) async {
        guard let account = app.current else { return }
        if account.isDemo {
            absences = Demo.absences(); homework = Demo.homework(); exams = Demo.exams(); notes = Demo.schoolNotes(); wall = Demo.wall()
            return
        }
        if !loadedCache {
            loadedCache = true
            absences = app.cache.load([Absence].self, as: "absences", for: account.id)
            homework = app.cache.load([Homework].self, as: "homework", for: account.id)
            exams = app.cache.load([Exam].self, as: "exams", for: account.id)
            notes = app.cache.load([SchoolNote].self, as: "notes", for: account.id)
            wall = app.cache.load([WallItem].self, as: "wall", for: account.id)
        }
        guard let session = app.session(for: account), !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let institute = account.instituteCode, id = account.id, cache = app.cache
        let service = SchoolDataService()
        // külön Task-ok: fülváltáskor se szakadjanak meg; egyik hibája nem rontja el a többit
        let from = Calendar.school.date(byAdding: .day, value: -30, to: Calendar.school.startOfDay(for: .now))!
        async let a = Task { try await service.absences(session: session, instituteCode: institute) }.result
        async let h = Task { try await service.homework(session: session, instituteCode: institute, from: from) }.result
        async let e = Task { try await service.exams(session: session, instituteCode: institute) }.result
        async let n = Task { try await service.notes(session: session, instituteCode: institute) }.result
        async let w = Task { try await service.wall(session: session, instituteCode: institute) }.result
        let results = await (a, h, e, n)
        if case .success(let v) = await w { wall = v; try? cache.save(v, as: "wall", for: id) }
        if case .success(let v) = results.0 { absences = v; try? cache.save(v, as: "absences", for: id) }
        if case .success(let v) = results.1 { homework = v; try? cache.save(v, as: "homework", for: id) }
        if case .success(let v) = results.2 { exams = v; try? cache.save(v, as: "exams", for: id) }
        if case .success(let v) = results.3 { notes = v; try? cache.save(v, as: "notes", for: id) }
        for r in [results.0.error, results.1.error, results.2.error, results.3.error] {
            if case KretaError.reloginRequired? = r { app.markNeedsRelogin(id); break }
        }
    }
}

/// A saját füzet: azonnal mentődik a telefonra.
@Observable
final class NotebookModel {
    private(set) var notebook = Notebook()
    private var accountID: String?
    private var cache: AccountCache?

    func open(_ app: AppModel) {
        guard let id = app.current?.id, id != accountID else { return }
        accountID = id
        cache = app.cache
        notebook = app.cache.load(Notebook.self, as: "notebook", for: id) ?? Notebook()
    }

    func update(_ change: (inout Notebook) -> Void) {
        change(&notebook)
        if let accountID { try? cache?.save(notebook, as: "notebook", for: accountID) }
    }
}

private extension Result {
    var error: Failure? { if case .failure(let e) = self { e } else { nil } }
}
