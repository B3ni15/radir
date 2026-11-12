# Radír

Nem hivatalos, natív iOS e-KRÉTA kliens (SwiftUI, iOS 18+, iOS 26-tól Liquid Glass).
A Filc → reFilc → Firka család folytatása. Licenc: AGPL-3.0.

## Felépítés

- `Radir/` – az app (SwiftUI nézetek, `AppModel`)
- `RadirKit/` – helyi Swift package: KRÉTA login és kliens, fiókok, színek. Tesztek: `cd RadirKit && swift test`
- `docs/superpowers/` – terv és megvalósítási tervek

## Futtatás

```bash
xcodebuild -project Radir.xcodeproj -scheme Radir -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build
```

Vagy nyisd meg a `Radir.xcodeproj`-ot Xcode-ban. Demó fiók a login képernyőn: „Kipróbálom demóval” (Debug, TestFlight és App Review buildben; élesben a logó 2 mp-es nyomására jelenik meg).
