# MoneyPaperSync

Natives macOS-Tool (SwiftUI, macOS 14+): überwacht den MoneyMoney-Statements-Ordner, erkennt Bank/Konto/Zeitraum
lokal und archiviert die Kontoauszüge in Paperless-ngx. Design: Dark Glass, Logo V4 – Dokumentenfokus, Akzent Blau.

## Bauen

1. `brew install xcodegen`
2. Im Projektordner (dort liegt `project.yml`): `xcodegen generate`
3. `open MoneyPaperSync.xcodeproj` → Signing-Team wählen → ⌘R

Das Projekt wurde ohne Xcode geschrieben und **noch nicht kompiliert**. Beim ersten Build sind kleinere
Compiler-Korrekturen wahrscheinlich. Sprachmodus ist Swift 5 (Toolchain Swift 6/Xcode 16); die Umstellung auf
Swift-6-Modus steht in `project.yml`.

Icons neu erzeugen: `python3 scripts/make_icons.py` (Pillow).

## Struktur

```
MoneyPaperSync/
  App/        App-Einstieg, AppEnvironment, RootView/MainView
  Design/     DesignSystem, ColorPalette, Typography, Spacing, GlassStyles, Components/
  Models/     SwiftData: Bank, Account, StatementDocument, LogEntry + Enums
  Services/   AppSettings, Keychain, PaperlessClient, PDFAnalyzer, FolderWatcher, SyncEngine, Log/Notifications
  Views/      Dashboard, Dokumente (+Detail), Warteschlange, Konten, Banken, Protokoll, Einstellungen, Onboarding
  Resources/  Assets.xcassets (AppIcon, LogoMono)
```

## Verhalten

- Ordner: Sandbox, Security-Scoped Bookmark, **nur Lesezugriff** (Originale bleiben unverändert). Überwachung per
  FSEvents plus regelmäßiger Abgleich.
- Analyse (lokal): PDF-Validierung, SHA-256, IBAN-Erkennung (Prüfsumme, nur maskiert gespeichert), Bank per
  PDF-Text (Dateiname allein führt zu „Manuelle Prüfung“), Zeitraum aus Datumsangaben.
- Upload: `POST /api/documents/post_document/`, danach Task-Polling (`/api/tasks/`). Standardmäßig 1 paralleler
  Upload (max. 3), temporäre Fehler werden automatisch nach dem Retry-Intervall wiederholt.
- Token: ausschließlich im Schlüsselbund. Protokoll wird von IBANs/Tokens bereinigt.
- Banken: werden nie automatisch angelegt. „Standardbanken hinzufügen“ ist eine ausdrückliche Aktion.
  Konten werden bei erkannter IBAN automatisch angelegt oder manuell gepflegt.

## Bekannte Grenzen / zu prüfen am Mac

- Kompilierung und UI-Feinschliff (Blur-Performance, Fokus-Ringe, VoiceOver) sind ungetestet.
- Datums-/Zeitraumerkennung ist heuristisch; bei Fehlern „Erkennung bearbeiten“ nutzen.
- Paperless-Task-Antworten unterscheiden sich leicht je nach Version (Feld `related_document`).
- „Beim Anmelden starten“ benötigt eine signierte App (SMAppService).
