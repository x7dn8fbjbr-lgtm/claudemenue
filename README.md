# ClaudeMenue

> **Vibe coded with Claude.** Dieses Projekt wurde vollständig mit [Claude Code](https://claude.ai/claude-code) (Anthropic) entwickelt — von der Idee über das Design bis zur Implementierung. Kein manuell geschriebener Code.

Ein macOS-Menüleisten-Assistent: Gedanken eintippen, Claude entscheidet autonom was damit passiert — Todoist-Task erstellen, neue Obsidian-Notiz anlegen oder eine bestehende ergänzen. Kein Bestätigungsdialog, kein Nachfragen.

---

## Wie es funktioniert

```
Eingabe (Text)
  → Claude API (Function Calling)
  → Claude entscheidet: Todoist / Obsidian-Notiz (neu) / Obsidian-Notiz (ergänzen)
  → Ergebnis erscheint kurz im Panel
```

Claude trifft die Entscheidung vollständig autonom — basierend auf einem fest eingebetteten Projektprofil im System-Prompt.

---

## Features

- **Menüleisten-App** — kein Dock-Icon, immer verfügbar
- **Globaler Shortcut** `⌘⇧J` — öffnet das Eingabefenster aus jeder App
- **Markdown-Rendering** im Eingabefeld (`**fett**`, `*kursiv*`)
- **Todoist** — Tasks erstellen inkl. Fälligkeitsdatum (natürliche Sprache)
- **Obsidian** — neue Notizen anlegen oder bestehende ergänzen (direkter Dateisystem-Zugriff)
- **API Keys sicher im macOS Keychain** gespeichert
- 23 XCTests

---

## Voraussetzungen

- macOS 14 (Sonoma) oder neuer
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Anthropic API Key ([console.anthropic.com](https://console.anthropic.com))
- Todoist API Token (Todoist → Einstellungen → Integrationen)
- Obsidian Vault (Pfad in `ClaudeService.swift` anpassen)

---

## Installation & Build

```bash
git clone https://github.com/x7dn8fbjbr-lgtm/claudemenue.git
cd claudemenue
xcodegen generate
open ClaudeMenue.xcodeproj
```

In Xcode: **⌘R** zum Starten.

### Erster Start

1. Einstellungsfenster öffnet sich automatisch
2. Anthropic API Key + Todoist Token eintragen → Sichern
3. macOS fragt nach **Bedienungshilfen**-Berechtigung → erlauben (für globalen Shortcut)
4. Notification-Berechtigung erlauben

---

## Konfiguration

Das Projektprofil (wer bist du, welche Projekte hast du) ist in `ClaudeService.swift` als System-Prompt eingebettet. Für eigene Nutzung anpassen:

```swift
private let systemPrompt = """
Du bist der persönliche Assistent von [Name].
...
"""
```

Der Obsidian-Vault-Pfad ist in `ObsidianService.swift` konfiguriert.

---

## Architektur

| Komponente | Datei | Aufgabe |
|---|---|---|
| `ClaudeService` | `Services/ClaudeService.swift` | Anthropic API + Function Calling |
| `TodoistService` | `Services/TodoistService.swift` | Todoist REST API |
| `ObsidianService` | `Services/ObsidianService.swift` | Filesystem-Zugriff auf Vault |
| `NotificationService` | `Services/NotificationService.swift` | macOS Notifications |
| `SettingsStore` | `Settings/SettingsStore.swift` | Keychain-Wrapper |
| `InputWindowController` | `Window/InputWindowController.swift` | Schwebendes NSPanel |
| `MenuBarManager` | `App/MenuBarManager.swift` | NSStatusItem |
| `HotKeyManager` | `App/HotKeyManager.swift` | Carbon RegisterEventHotKey |

---

## Lizenz

MIT — mach damit was du willst.

---

*Gebaut mit Claude Code von Anthropic. Vibe Coding at its finest.*
