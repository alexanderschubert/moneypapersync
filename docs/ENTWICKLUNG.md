# Entwicklung: Branches und Builds

MoneyPaperSync ist eine native macOS-App (SwiftUI, macOS 14+). Es gibt kein Docker-Image; Ergebnis eines Builds ist ein DMG.

| Branch | Zweck | Build |
|---|---|---|
| `main` | freigegebener Stand | DMG als Artefakt der CI |
| `dev` | Stand zum Ausprobieren | DMG als Artefakt der CI |
| `feat/...`, `fix/...` | eine einzelne Änderung | wird beim Pull Request gebaut |

## Lokal bauen

```bash
brew install xcodegen          # einmalig
xcodegen generate
xcodebuild -scheme MoneyPaperSync -destination 'platform=macOS' build
xcodebuild -scheme MoneyPaperSync -destination 'platform=macOS' test   # UI-Tests, brauchen Bedienungshilfe-Freigabe
```

Die Datei `MoneyPaperSync.xcodeproj` wird aus `project.yml` erzeugt und gehört nicht ins Repo.

## Ablauf

1. Von `dev` einen Branch abzweigen: `git checkout dev && git pull && git checkout -b feat/name`.
2. Pull Request **nach `dev`**. Die CI muss grün sein.
3. Das DMG aus dem Lauf auf dem Mac ausprobieren.
4. Passt alles, Pull Request **`dev` → `main`**, als **Merge-Commit** (kein Squash).

Kleinigkeiten wie ein Tippfehler dürfen direkt als Pull Request nach `main`; danach `main` in `dev` mergen.

## Aufräumen

Gemergte Feature-Branches löscht der Workflow `branches.yml` automatisch. `main` und `dev` bleiben immer stehen; deshalb ist in den Repo-Einstellungen „Automatically delete head branches“ abgeschaltet.
