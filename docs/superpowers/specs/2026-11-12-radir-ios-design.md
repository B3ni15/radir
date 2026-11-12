# Radír – natív iOS app (terv)

2026-11-12 · Állapot: jóváhagyásra vár

## Miért

A Firka (reFilc legacy) egy Flutterben írt, nem hivatalos e-KRÉTA kliens: kb. 57 ezer sor Dart kód 4 csomagban (`refilc`, `refilc_kreta_api`, `refilc_mobile_ui`, `refilc_plus`), a forrás a `/Users/benedekballo/Documents/app-legacy` mappában. A tulajdonos újraírja natív Swift/SwiftUI-ban, új néven (**Radír**). Így iOS 26-on valódi Liquid Glass lesz rajta, és minden iOS-es képernyő natív érzetű. A legacy Flutter app nem változik, az Androidosok azt használják tovább.

**Siker:** a tulajdonos és a diákok a Firka helyett a Radírt használják nap mint nap, és semmi nem hiányzik nekik a régi appból.

## Célok

- A legacy app **összes funkciója** átjön, és semmi nem kerül ki (a tulajdonos döntése). Kivétel csak az lehet, ami a Firka szerverén vagy fizetésen múlik (lásd: Nem célok).
- A régi **Plus mindenkinek ingyenes**: nincs aktiválás, tier, scope-ellenőrzés, fizetés vagy upsell.
- **Liquid Glass iOS 26-tól, alap iOS kinézet iOS 18–25-ön** (a tulajdonos döntése).
- Ahol nincs üveg, ott **a régi kinézet marad**: a kártyák, jegyszínek, tile-ok és a tipográfia a legacyt követik.
- **Lépésről lépésre** épül, minden képernyő sorra kerül (a tulajdonos döntése). Minden fázis végén kipróbálható app van a szimulátorban.

## Nem célok

- Android, iPad-optimalizált elrendezés, Mac.
- Fizetés, Plus aktiválás, Stripe, upsell, támogatói lista, reklámok.
- Hibajelentés a Firka szerverre, mert az Apple crash report és a TestFlight lefedi.
- GitHub-os frissítéskeresés, mert az App Store frissít.
- Analytics.
- Adatátvitel a Firkából, mert külön app, és nem fér hozzá a Firka adataihoz. A felhasználó újra bejelentkezik.

## Anti-célok (ezek kudarcnak számítanak, még ha működik is az app)

- Egy Flutter UI egy az egyben lemásolva: a Radírnak iOS-es érzetűnek kell lennie.
- Üvegutánzat iOS 18-on: régi iOS-en a sima rendszerkinézet a helyes.
- Bármi, ami a diák KRÉTA adatait vagy tokenjét a saját szerverünkön kívül máshova küldi, vagy logolja.
- Fizetős fal vagy „Plus” felirat bárhol.

## Korlátok

- **Minimum iOS 18.** iOS 26-tól Liquid Glass. A rendszer saját elemei (tab bar, toolbar, sheet, gombok) a 26-os SDK-val maguktól üvegesek. Saját üveg elemnél `if #available(iOS 26, *)` mellett `glassEffect`, különben sima material.
- **Xcode 27.2** van a gépen. A teszteléshez az iOS Simulator használható, minden fázis ott ellenőrizhető.
- **Licenc: AGPL-3.0**, mert a legacy logikája átkerül. A Radír forrása is nyílt marad, a credit a Filc/reFilc/Firka csapatot illeti, és ez az appban is látszik (Névjegy).
- **KRÉTA:** nem hivatalos API, ugyanazokkal a végpontokkal és a `kreta-ellenorzo-student-mobile-ios` client_id-val, mint a legacy (`refilc_kreta_api/lib/client/api.dart`). Az összes ellenorzo V3, kommunikációs, eügyintézés- és fájlvégpont onnan jön.
- **Login:** OAuth + PKCE az `idp.e-kreta.hu`-n. A redirect URI `https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect`, ez nem a mi domainünk. Ezért `ASWebAuthenticationSession` nem használható, egy `WKWebView`-nak kell elkapnia a redirectet, ahogy a legacy is csinálja (`kreten_login.dart`).
- **Márka:** a név Radír, a logó a „Tömb” (kétszínű piros-kék radírtömb, mélységgel). Domain `radirapp.hu`, bundle ID `hu.radirapp.ios`. Paletta: ceruzapiros a figyelmeztetésekhez, tollkék a márkaszínhez és az aktív elemekhez, mellette füzetlap. A vázlatok: https://claude.ai/artifact/RG5nYd2JNrt1saLRbnUeHg. A végleges ikon Icon Composerben készül, világos, sötét és tinted változattal.
- **Saját szerver** (`refilc-live-server`, Rust; a legacy a `https://legacy-la.devbeni.lol` címen éri el, a Radír is ezt használja, egy konstansban):
  - Live Activity: `POST /register`, `/schedule`, `/unregister`. A Radír a saját bundle ID-jával regisztrál, `app_type: "refilc"` formátummal, így a szerveren nem kell változtatni.
  - Témamegosztás: `/theme`, `/theme/color`, `/themes`, `/themes/mine` és a DELETE-ek. Íráshoz `Authorization: Bearer <KRÉTA access token>` kell.
  - Hírek és config: `GET /news`, `GET /config`. A `user_agent` vészfék: a KRÉTA-hívások user agentje innen frissíthető.
  - A szerver API-ja a `refilc-live-server/README.md`-ben van.

## Amit a tulajdonos döntött

- Teljes újraírás Swiftben, a csak-rebrand helyett.
- Minden Plus funkció ingyenes.
- Név: Radír, logó: Tömb, domain: radirapp.hu.
- Liquid Glass ott, ahol természetes, mindenhol máshol a régi kinézet. Minimum iOS 18, azon alap kinézettel.
- A Live Activity marad. A hírek és a config a saját szerverről jönnek. A crash report, a frissítéskeresés és a fizetés kimarad.
- Szerkesztés témáknál: a módosított téma új feltöltés, új id-val, a saját nevén. A régit a tulajdonosa törölheti.
- Semmi nem esik ki, és minden képernyő lépésről lépésre épül.

## Funkcióleltár (paritás a legacyval)

A forrásban a mappák: `refilc_mobile_ui/lib/pages`, `…/screens`, `refilc_plus/lib/ui/mobile`.

| Terület | Tartalom |
|---|---|
| **Bejelentkezés, fiókok** | KRÉTA WebView login, tokenfrissítés, több fiók és váltás köztük, kijelentkezés, becenév, profilkép, demó mód (a legacy `demo_data.dart` alapján, az App Store review-hoz is kell) |
| **Kezdőlap** | Live card (óra alatt, szünetben, visszaszámlálás), üdvözlő üzenet, legutóbbi jegyek, dolgozatok, házik, faliújság és hiányzások feedje, „új” jelölés |
| **Jegyek** | tantárgylista átlagokkal, félév vagy év választása, osztályátlag, grafikon, jegydarabszám, bukásveszély-jelzés, tantárgyi nézet, jegy részletei, jegykalkulátor, céltervező (cél → szükséges jegyek, követés) |
| **Órarend** | heti nézet, napváltás, A/B hét (és csere), szünetek mutatása, óraszám, helyettesítés és elmaradt óra jelölése, teljes képernyős órarend, csengetési eltolás |
| **Jegyzetek fül** | házi feladatok (csatolmányokkal), bejelentett számonkérések, saját jegyzetek (szöveg és kép), teendők |
| **Hiányzások** | tantárgyankénti bontás, igazolt, igazolatlan és késés, összesítők |
| **Üzenetek** | bejövő, elküldött, kuka, olvasás, csatolmányok letöltése, új üzenet címzettválasztással és csatolmánnyal, törlés |
| **Egyéb KRÉTA** | feljegyzések, faliújság, tanulói adatlap |
| **Hírek** | lista és részletek a saját `/news`-ból, a `seen_news` jelöléssel |
| **Év végi összefoglaló** | kezdő, jegyek, órák, „személyiség” és összesítő oldal |
| **Beállítások** | általános (nyelv, kezdőoldal, kerekítés, A/B hét, csengetési eltolás, rezgés, prezentációs mód), megjelenés (világos/sötét, akcentus- és egyedi színek, betűtípus, árnyék, jegyszínek, alkalmazásikon), témák (saját, megosztás, letöltés kóddal, `/themes` galéria, saját témák törlése), tantárgy- és tanár-átnevezés (dőlt jelöléssel), Live Activity (beleegyezés, szín, adatvédelmi oldal), naptárszinkron (EventKit, terem, tanár, dolgozatok), jegyexport, üdvözlő üzenet, extrák (uwu mód, „jegynyitás” animáció), adatvédelem, névjegy és licencek |

A legacy beállításkulcsai (`refilc/lib/models/settings.dart`, kb. 140 mező) a beállítások teljes listáját adják. Ami ott Plus volt, itt alapból elérhető.

## Felépítés (a tervező javaslata, a tulajdonos nem döntött róla)

- **SwiftUI + Observation (`@Observable`)**, `async/await` + `URLSession`. Külső függőség nincs: grafikonhoz Swift Charts, tároláshoz SwiftData, tokenhez Keychain, naptárhoz EventKit, Live Activityhez ActivityKit.
- **Felosztás:**
  - `Radir` (app target)
  - `RadirKit` (helyi Swift package: KRÉTA kliens, modellek, átlag- és kalkulátorlogika, parse-olás, `swift test`-tel tesztelhető)
  - `RadirLiveActivity` (widget extension, a legacy `ios/livecard` Swift kódjára építve)
  - App Group a target-ek között.
- **Adat:** a KRÉTA-válaszok helyben cache-elődnek fiókonként, így offline is látszik az utolsó állapot. Frissítés indításkor és lehúzással (pull-to-refresh). A saját jegyzetek, a teendők, a célok és az átnevezések csak helyben vannak.
- **Téma:** egy téma-motor, ami a legacy színeit (háttér, panel, akcentus, ikon, jegyszínek) adja a nézeteknek. Ugyanez a modell megy a megosztó szerverre is, ARGB egészként.
- **Nyelvek:** magyar, angol és német, String Catalog (`.xcstrings`), a legacy i18n fájljaiból.

## Építési sorrend

Minden fázis végén: build, unit tesztek a `RadirKit`-ben, kipróbálás az iOS szimulátorban (iOS 26 és iOS 18 runtime-on is, ha van), aztán a tulajdonos megnézi.

1. **Alap:** Xcode projekt, `RadirKit`, téma-motor, tab bar váz (üveg iOS 26-on, alap iOS 18-on), nyelvi váz, márkaszínek, ideiglenes ikon, demó adatok.
2. **Login és fiókok:** WebView login PKCE-vel, tokenfrissítés, Keychain, több fiók, demó mód.
3. **Jegyek:** lista, átlagok, tantárgyi nézet, jegy részletei, grafikon, osztályátlag.
4. **Órarend:** heti nézet, A/B hét, helyettesítések, teljes képernyős nézet.
5. **Kezdőlap és Live Activity:** live card, feed, Live Activity és regisztráció a szerverre.
6. **Hiányzások.**
7. **Jegyzetek fül:** házik, számonkérések, saját jegyzetek, teendők.
8. **Üzenetek, feljegyzések, faliújság.**
9. **Jegykalkulátor és céltervező.**
10. **Beállítások teljesen:** megjelenés, témák és megosztás, jegyszínek, alkalmazásikonok, átnevezés, naptárszinkron, export, extrák.
11. **Hírek és év végi összefoglaló.**
12. **Csiszolás és App Store:** végleges ikon, akadálymentesség (VoiceOver, Dynamic Type), adatvédelmi címkék, TestFlight.

## A tervező döntései (ellenőrizendő)

- **Push-értesítések (új jegy, hiányzás, üzenet):** a legacyban ki vannak kommentezve (`notification_helper.dart`, 719 sorból 689), vagyis most nem működnek. Ezért nincsenek a paritásban. Később külön fázisként jöhetnek.
- **Felhőszinkron** (`cloud_sync_*`): a Firka szerverén futott, ezért kimarad.
- **Ikoncsomag-választó** (Material vagy Cupertino): kimarad, mindenhol SF Symbols lesz.
- **Csak iPhone:** iPadon az iPhone-os elrendezés fut.
- **PKCE:** minden loginnál új kulcs. A legacyban beégetett `code_verifier` van.
- **Fejlesztői mód és a hamis Live Activity órák:** csak Debug buildben.

## A tervezőre bízva

- A képernyők pontos SwiftUI-szerkezete, az animációk, és hogy hol legyen saját üvegelem.
- A cache sémája és a frissítési stratégia részletei.
- A tesztek köre: legalább a parse-olás (a legacy demó JSON-jaival), az átlag- és kerekítési logika, a kalkulátor és a céltervező.
- A git repo létrehozása a `radir` mappában. GitHubra csak a tulajdonos kérésére kerül.
