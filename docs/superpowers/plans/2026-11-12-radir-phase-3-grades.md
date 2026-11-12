# Radír 3. fázis: Jegyek – megvalósítási terv

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A Jegyek fül a legacy összes jegynézetével (kivéve a kalkulátort és a céltervezőt, azok a 9. fázisban jönnek): tantárgylista átlaggal, osztályátlaggal és trenddel, halmozott átlag grafikon, jegyeloszlás, tantárgyi nézet, jegy részletei. Demóban és valódi KRÉTA fiókkal is.

**Architecture:** A modell, a parse-olás, az átlagok és a letöltés a `RadirKit`-ben van, és tesztelt (`swift test`). Az app egy `GradesModel`-t tart a kiválasztott fiókhoz: először a gyorsítótárat mutatja, aztán frissít. A UI az előző lépésben készült design rendszerre épül (PanelGroup, PanelRow, AverageBadge), a grafikon Swift Charts.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-12-radir-ios-design.md`

## Global Constraints

- Minden szabály a legacyból (`refilc_kreta_api/lib/models/grade.dart`, `refilc/lib/helpers/average_helper.dart`, `refilc_mobile_ui/lib/pages/grades/*`):
  - Szöveges értékelés (`peldas`, `jo`, `valtozo`, `rossz`, `hanyag`, ékezet nélkül, kisbetűvel), ha `SzamErtek == 0`: érték 5/4/3/2/1, súly 0.
  - A `SzovegesErtek` a „(” előtti rész.
  - Átlag: `Σ(érték × súly/100) / Σ(súly/100)` az évközi (`evkozi_jegy_ertekeles`) jegyekre; a 0 értékű jegy kimarad; súly nélkül nincs átlag (nil).
  - Kerekítés a jegyszínhez: `érték >= floor + 0.5` → felfelé (a legacy alap `rounding: 5`).
  - Grafikon: újabb → régebbi sorrendben csoportok, új csoport ha két szomszédos jegy között több mint `gapDays` nap van (főoldal 2, tantárgy 5); pontonként a csoport legújabb dátuma és az addigi összes jegy átlaga.
  - Időszak: Év (0), 3 hónap (90), 30, 14, 7 nap. A grafikon csak az időszak jegyeit mutatja, a trend a mostani átlag és az időszak előtti átlag különbsége.
  - Osztályátlag: `OsztalyCsoportok[0].OktatasNevelesiFeladat.Uid` → `Ertekelesek/Atlagok/OsztalyAtlagok?oktatasiNevelesiFeladatUid=`.
  - Tantárgyak ábécérendben.

## Review Focus

1. Csak szöveges (magatartás/szorgalom) jegy egy tantárgyban: nincs átlag, nem 0,00 → `averageIgnoresBehaviorAndZero`.
2. Hiányzó mezők a KRÉTA válaszban (nincs `Tipus`, `Mod`, `RogzitesDatuma`): a jegy betöltődik → `gradeDecodesWithMissingFields`.
3. Az osztályátlag letöltése hibázik: a jegyek ettől még megjelennek → `classAverageFailureKeepsGrades`.
4. Üres jegylista (új tanév): üres állapot, nem hiba → UI.
5. Offline indulás: a gyorsítótárból jönnek a jegyek → `cacheRoundTrip`.

---

### Task 1: Jegymodell és parse-olás
`RadirKit/Sources/RadirKit/Grades/Grade.swift`; teszt: `GradeTests.swift`, fixture `Fixtures/Ertekelesek.json`.
- `struct Subject: Codable, Hashable, Identifiable, Sendable { id, name, categoryName }`
- `enum GradeKind: String, Codable { midYear, firstQ, secondQ, halfYear, thirdQ, fourthQ, endYear, levelExam, unknown }`
- `struct Grade: Codable, Identifiable, Hashable, Sendable { id, date, writeDate, value: Int, valueName, shortName, weight: Int, kind, subject, topic, mode, teacher, valueTypeID }`, KRÉTA DTO-ból (`KretaGrade: Decodable`).

### Task 2: Átlagok, kerekítés, idővonal, eloszlás
`RadirKit/Sources/RadirKit/Grades/Averages.swift`; teszt: `AveragesTests.swift`.
- `enum Averages { static func weighted(_:) -> Double?; static func roundedGrade(_:threshold:) -> Int; static func timeline(_:gapDays:) -> [AveragePoint]; static func distribution(_:) -> [Int: Int] }`

### Task 3: Jegynapló (letöltés, cache, demó)
`RadirKit/Sources/RadirKit/Grades/GradeBook.swift`, `.../Grades/GradesService.swift`, `.../Storage/AccountCache.swift`, `Demo/DemoGrades.swift`; teszt: `GradesServiceTests.swift`.
- `struct ClassAverage: Codable { subjectID, average }`; `struct GradeBook: Codable { grades, classAverages, fetchedAt; subjects; grades(for:kinds:); classAverage(for:) }`
- `struct GradesService { func fetch(session: KretaSession, instituteCode:) async throws -> GradeBook }` – osztályátlag hibája nem buktatja el.
- `struct AccountCache { init(root:); func load<T>(_:for:) ; func save(_:for:) }`
- `Demo.gradeBook(now:)`

### Task 4: Jegyek fül
`Radir/Grades/GradesModel.swift`, `GradesView.swift`, `AverageChart.swift`, `GradeDistribution.swift`, `SubjectIcon.swift`.

### Task 5: Tantárgy és jegy részletei
`Radir/Grades/SubjectView.swift`, `GradeRow.swift`, `GradeDetailSheet.swift`. Szimulátorban demóval végignézni, világos és sötét módban.
