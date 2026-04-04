# ClaudeMenue — Design Spec
**Datum:** 2026-04-03  
**Status:** Genehmigt

---

## Überblick

macOS-Menüleisten-App in Swift/SwiftUI. Detlef tippt einen Gedanken ein, schickt ihn ab — Claude entscheidet autonom via Function Calling, was damit passiert (Todoist-Task, neue Obsidian-Notiz, bestehende Obsidian-Notiz ergänzen). Keine Rückfragen, keine Bestätigung. Rückmeldung via macOS-Notification.

---

## Architektur & Komponenten

| Komponente | Aufgabe |
|---|---|
| `MenuBarManager` | NSStatusItem, Icon, öffnet/schließt Eingabefenster |
| `HotKeyManager` | Globale Tastenkombination (Standard: ⌘⇧Space) via Carbon/Cocoa |
| `InputWindow` | Schwebendes Panel, Bildschirmmitte, Markdown-fähiges Textfeld |
| `ClaudeService` | Anthropic API, Function Calling, schickt Eingabe + Projektprofil |
| `TodoistService` | Todoist REST API — Task anlegen |
| `ObsidianService` | Dateisystem — Notiz anlegen oder bestehende ergänzen |
| `NotificationService` | macOS UserNotifications — Rückmeldung nach Aktion |
| `SettingsStore` | API Key + Todoist Token sicher in macOS Keychain |

**Datenfluss:**
```
Eingabe (Text)
  → ClaudeService (Projektprofil als System-Prompt + Tool-Definitionen)
  → Claude wählt Tool(s) via Function Calling
  → TodoistService / ObsidianService (parallel möglich)
  → NotificationService ("Task erstellt" / "Notiz gespeichert")
```

---

## Eingabefenster & UX

- **Fenstertyp:** Schwebendes Panel ohne Standard-Chrome (ähnlich Spotlight)
- **Position:** Bildschirmmitte
- **Größe:** ca. 600×200px
- **Schließen:** `Escape` oder Klick außerhalb
- **Abschicken:** `⌘Return` oder Senden-Button
- **Textfeld:** Mehrzeilig, Markdown-Rendering (fett, kursiv, Listen) via `AttributedString`
- **Placeholder:** *"Was liegt dir auf dem Herzen?"*
- **Stil:** Angelehnt an Claude Desktop App — dunkler Hintergrund, helle Schrift, dezenter Akzent

**Menüleisten-Icon:**
- SF Symbol `bubble.left.and.text.bubble.right` (oder ähnliches)
- Ladeindikator während Claude arbeitet
- Rechtsklick-Menü: "Einstellungen", "Beenden"

**Einstellungen:**
- Minimalfenster: Anthropic API Key + Todoist API Token eingeben
- Speicherung in macOS Keychain

---

## Claude Function Calling

**System-Prompt (fest eingebettet):**
```
Du bist der persönliche Assistent von Detlef Hoefer. 
Detlef schickt dir kurze Gedanken, Ideen oder Aufgaben. 
Du entscheidest autonom, was damit zu tun ist, und rufst die passenden Tools auf.
Antworte nicht mit Text — nur mit Tool-Calls.

Projekte von Detlef:
- Beruf/Consulting: Hoefer Consulting, DB InfraGO (FSQ IT, FBQ, BahnGPT)
- Privat: Wärmepumpe & PV, Familiengeschichte, Stammbaum, Finanzen/Steuer, Arztsuche
- Obsidian Vault: ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/mylife/
- Neue Notizen immer in: 00_INBOX/
```

**Tool-Definitionen:**

| Tool | Parameter | Wann aufrufen |
|---|---|---|
| `create_todoist_task` | `title` (required), `description` (optional), `project` (optional), `due_date` (optional) | Eingabe klingt nach Aufgabe/TODO/Erledigung |
| `create_obsidian_note` | `filename` (required), `content` (required), `folder` (optional, default: `00_INBOX`) | Neuer Gedanke, Idee, Information ohne bestehenden Kontext |
| `update_obsidian_note` | `filename` (required), `content_to_append` (required) | Ergänzung zu einem bestehenden Thema/Projekt |

> **Hinweis `update_obsidian_note`:** Claude leitet den Dateinamen aus dem Kontext der Eingabe ab (z.B. "Wärmepumpe" → `waermepumpe-solar.md`). Existiert die Datei nicht, fällt Claude auf `create_obsidian_note` zurück. In v1 kein Verzeichnis-Scan — Claude kennt die Dateinamen aus dem eingebetteten Projektprofil.

Claude kann mehrere Tools gleichzeitig aufrufen (z.B. Todoist-Task + Obsidian-Notiz für denselben Gedanken).

---

## Fehlerbehandlung

| Fehler | Verhalten |
|---|---|
| Kein API Key konfiguriert | Notification: "Bitte API Key in Einstellungen eintragen" |
| Claude API Fehler | Notification: "Fehler beim Senden an Claude" — Eingabe bleibt im Fenster |
| Todoist API Fehler | Notification: "Todoist-Task konnte nicht erstellt werden" |
| Obsidian nicht beschreibbar | Notification: "Obsidian-Notiz konnte nicht gespeichert werden" |
| Kein Netz | Sofortige Fehlermeldung, Eingabe bleibt erhalten |

---

## Setup-Voraussetzungen (einmalig)

1. Anthropic API Key von `console.anthropic.com`
2. Todoist API Token aus den Todoist-Einstellungen
3. macOS Accessibility-Berechtigung (für globale Hotkey-Erkennung)
4. Notification-Berechtigung (beim ersten Start)

---

## Nicht im Scope

- Eingabe-History / Log
- Konfigurierbare Obsidian-Zielordner (immer `00_INBOX/`)
- Mehrsprachige Erkennung (Detlef schreibt auf Deutsch)
- iCloud-Sync der Settings
- Onboarding-Flow

---

## Plattform

- macOS 14 (Sonoma) oder neuer
- Swift 5.9+, SwiftUI
- Kein App Store (direktes .app-Bundle)
