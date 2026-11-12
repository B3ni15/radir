import Foundation
import Observation
import RadirKit

/// A kiválasztott fiók jegyei: először a gyorsítótár, aztán frissítés a KRÉTA-ból.
@Observable
final class GradesModel {
    private(set) var book: GradeBook?
    private(set) var isLoading = false

    func load(_ app: AppModel) async {
        guard let account = app.current else { return }
        if account.isDemo {
            book = app.renaming.apply(Demo.gradeBook())
            return
        }
        if book == nil { book = app.cache.load(GradeBook.self, as: "grades", for: account.id).map(app.renaming.apply) }
        guard let session = app.session(for: account), !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // külön Task: ha a nézet eltűnik (fülváltás), a letöltés akkor is befejeződik
            let institute = account.instituteCode
            let fresh = try await Task { try await GradesService().fetch(session: session, instituteCode: institute) }.value
            book = app.renaming.apply(fresh)
            try? app.cache.save(fresh, as: "grades", for: account.id)
        } catch KretaError.reloginRequired {
            // teljes képernyős újra belépés jön, a tárolt adat addig is látszik
            app.markNeedsRelogin(account.id)
        } catch {
            // offline vagy KRÉTA hiba: csendben a tárolt adat marad
        }
    }
}
