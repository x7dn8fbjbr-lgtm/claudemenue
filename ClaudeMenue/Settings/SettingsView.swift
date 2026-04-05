import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClaudeMenue — Einstellungen"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 500)
        super.init(window: window)
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }
}

struct SettingsView: View {
    @State private var anthropicKey: String = ""
    @State private var todoistToken: String = ""
    @State private var userName: String = ""
    @State private var projectContext: String = ""
    @State private var obsidianVaultPath: String = ""
    @State private var knownObsidianFiles: String = ""
    @State private var obsidianInboxFolder: String = ""
    @State private var savedFeedback = false
    @State private var isGenerating = false
    @State private var generateError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                apiTab.tabItem { Label("API Keys", systemImage: "key.fill") }
                contextTab.tabItem { Label("Kontext", systemImage: "person.fill") }
            }

            Divider()

            HStack {
                if savedFeedback {
                    Label("Gespeichert", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.subheadline)
                }
                Spacer()
                Button("Speichern") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
        }
        .onAppear { load() }
    }

    // MARK: - API Tab

    private var apiTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                fieldBlock(label: "Anthropic API Key") {
                    SecureField("sk-ant-…", text: $anthropicKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Erstellen unter console.anthropic.com → API Keys")
                        .font(.caption).foregroundColor(.secondary)
                }

                fieldBlock(label: "Todoist API Token") {
                    SecureField("Token…", text: $todoistToken)
                        .textFieldStyle(.roundedBorder)
                    Text("todoist.com → Einstellungen → Integrationen → API Token")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Kontext Tab

    private var contextTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                fieldBlock(label: "Dein Name") {
                    TextField("Max Mustermann", text: $userName)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock(label: "Projekte & Kontext") {
                    TextEditor(text: $projectContext)
                        .font(.system(size: 13))
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))

                    HStack(spacing: 12) {
                        Text("Beschreibe deine Projekte, Themen und Schwerpunkte.")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        if isGenerating {
                            ProgressView().scaleEffect(0.7)
                            Text("Generiere…").font(.caption).foregroundColor(.secondary)
                        } else {
                            Button("↓ Aus CLAUDE.md") {
                                Task { await importFromClaudeMd() }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.accentColor)
                            .font(.caption)
                            .help("CLAUDE.md-Dateien aus ~/Claude/ einlesen und Kontext generieren")
                            .disabled(anthropicKey.isEmpty && (SettingsStore.shared.anthropicApiKey ?? "").isEmpty)

                            Button("✦ Von Claude generieren") {
                                Task { await generateContext() }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.accentColor)
                            .font(.caption)
                            .disabled(anthropicKey.isEmpty && (SettingsStore.shared.anthropicApiKey ?? "").isEmpty)
                        }
                    }
                    if let err = generateError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }

                fieldBlock(label: "Obsidian") {
                    HStack {
                        TextField("Vault-Pfad", text: $obsidianVaultPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Auswählen…") { browseVault() }
                            .controlSize(.small)
                    }
                    TextField("Inbox-Ordner (Standard: 00_INBOX)", text: $obsidianInboxFolder)
                        .textFieldStyle(.roundedBorder)
                    TextField("Bekannte Dateinamen: datei1.md, datei2.md, …", text: $knownObsidianFiles)
                        .textFieldStyle(.roundedBorder)
                    Text("Bekannte Dateinamen helfen Claude, bestehende Notizen zu ergänzen statt neue zu erstellen.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Hilfsfunktionen

    @ViewBuilder
    private func fieldBlock<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            content()
        }
    }

    private func browseVault() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Vault auswählen"
        if panel.runModal() == .OK, let url = panel.url {
            obsidianVaultPath = url.path
        }
    }

    private func importFromClaudeMd() async {
        let key = anthropicKey.isEmpty ? (SettingsStore.shared.anthropicApiKey ?? "") : anthropicKey
        guard !key.isEmpty else { return }

        isGenerating = true
        generateError = nil
        defer { isGenerating = false }

        // Alle CLAUDE.md Dateien in ~/Claude/ einsammeln (max. 3 Ebenen tief)
        let claudeDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Claude")
        var collected: [(path: String, content: String)] = []

        if let enumerator = FileManager.default.enumerator(
            at: claudeDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                // Maximal 3 Verzeichnisebenen tief
                let relative = url.path.replacingOccurrences(of: claudeDir.path + "/", with: "")
                guard relative.components(separatedBy: "/").count <= 3 else { continue }
                guard url.lastPathComponent == "CLAUDE.md" else { continue }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    collected.append((path: relative, content: content))
                }
            }
        }

        guard !collected.isEmpty else {
            await MainActor.run { generateError = "Keine CLAUDE.md-Dateien in ~/Claude/ gefunden." }
            return
        }

        let combined = collected.map { "### \($0.path)\n\($0.content)" }.joined(separator: "\n\n---\n\n")

        let prompt = """
        Ich habe folgende CLAUDE.md-Dateien aus meinem Claude-Arbeitsordner. \
        Sie beschreiben meine Projekte, meinen Hintergrund und meinen Kontext.

        Erstelle daraus einen kompakten, strukturierten Kontext-Text (max. 300 Wörter) \
        der als System-Prompt für meinen persönlichen Assistenten geeignet ist. \
        Fokus auf: Wer bin ich, welche Projekte laufen, welche Themen sind wichtig. \
        Keine Navigationshinweise oder technische Details über Claude selbst. \
        Auf Deutsch, in Stichpunkten.

        \(combined)
        """

        await callClaude(prompt: prompt, apiKey: key)
    }

    private func generateContext() async {
        let key = anthropicKey.isEmpty ? (SettingsStore.shared.anthropicApiKey ?? "") : anthropicKey
        guard !key.isEmpty else { return }

        isGenerating = true
        generateError = nil
        defer { isGenerating = false }

        let name = userName.isEmpty ? "dem Nutzer" : userName
        let existing = projectContext.isEmpty ? "" : "\n\nBisheriger Kontext (erweitern/verbessern):\n\(projectContext)"

        let prompt = """
        Ich möchte meinen persönlichen KI-Assistenten mit Kontext über mich füttern. \
        Hilf mir, eine prägnante Beschreibung meiner Projekte und Themen zu erstellen \
        für \(name).\(existing)

        Erstelle eine strukturierte Liste meiner Projekte und Themen \
        (Beruf, Privat, Hobbys, laufende Aufgaben). \
        Antworte auf Deutsch, knapp und strukturiert (max. 200 Wörter).
        """

        await callClaude(prompt: prompt, apiKey: key)
    }

    private func callClaude(prompt: String, apiKey: String) async {
        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = (json["content"] as? [[String: Any]])?.first,
               let text = content["text"] as? String {
                await MainActor.run { projectContext = text }
            } else {
                await MainActor.run { generateError = "Antwort konnte nicht verarbeitet werden." }
            }
        } catch {
            await MainActor.run { generateError = "Fehler: \(error.localizedDescription)" }
        }
    }

    private func load() {
        let s = SettingsStore.shared
        anthropicKey = s.anthropicApiKey ?? ""
        todoistToken = s.todoistApiToken ?? ""
        userName = s.userName
        projectContext = s.projectContext
        obsidianVaultPath = s.obsidianVaultPath
        knownObsidianFiles = s.knownObsidianFiles
        obsidianInboxFolder = s.obsidianInboxFolder
    }

    private func save() {
        let s = SettingsStore.shared
        s.anthropicApiKey = anthropicKey.isEmpty ? nil : anthropicKey
        s.todoistApiToken = todoistToken.isEmpty ? nil : todoistToken
        s.userName = userName
        s.projectContext = projectContext
        s.obsidianVaultPath = obsidianVaultPath
        s.knownObsidianFiles = knownObsidianFiles
        s.obsidianInboxFolder = obsidianInboxFolder.isEmpty ? "00_INBOX" : obsidianInboxFolder
        savedFeedback = true
        NotificationCenter.default.post(name: .claudeMenueSettingsSaved, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedFeedback = false }
    }
}

extension NSNotification.Name {
    static let claudeMenueSettingsSaved = NSNotification.Name("de.hoeferconsulting.ClaudeMenue.settingsSaved")
}
