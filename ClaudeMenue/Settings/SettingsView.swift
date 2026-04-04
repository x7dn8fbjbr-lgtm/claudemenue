import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 540),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClaudeMenue — Einstellungen"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 480)
        super.init(window: window)
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }
}

struct SettingsView: View {
    // API Keys
    @State private var anthropicKey: String = ""
    @State private var todoistToken: String = ""
    // Kontext
    @State private var userName: String = ""
    @State private var projectContext: String = ""
    @State private var obsidianVaultPath: String = ""
    @State private var knownObsidianFiles: String = ""
    @State private var obsidianInboxFolder: String = ""

    @State private var savedFeedback = false

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
                        .foregroundColor(.green)
                        .font(.subheadline)
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
        Form {
            Section {
                SecureField("sk-ant-…", text: $anthropicKey)
                Text("Erstellen unter console.anthropic.com → API Keys")
                    .font(.caption).foregroundColor(.secondary)
            } header: { Text("Anthropic API Key") }

            Section {
                SecureField("Token…", text: $todoistToken)
                Text("todoist.com → Einstellungen → Integrationen → API Token")
                    .font(.caption).foregroundColor(.secondary)
            } header: { Text("Todoist API Token") }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }

    // MARK: - Kontext Tab

    private var contextTab: some View {
        Form {
            Section {
                TextField("z.B. Max Mustermann", text: $userName)
            } header: { Text("Dein Name") }

            Section {
                TextEditor(text: $projectContext)
                    .font(.system(size: 13))
                    .frame(minHeight: 100)
                Text("Beschreibe deine Projekte, Themen und Schwerpunkte. Je mehr Kontext, desto besser entscheidet Claude.")
                    .font(.caption).foregroundColor(.secondary)
            } header: { Text("Projekte & Kontext") }

            Section {
                HStack {
                    TextField("~/Library/Mobile Documents/…", text: $obsidianVaultPath)
                    Button("Auswählen…") { browseVault() }
                        .controlSize(.small)
                }
                TextField("00_INBOX", text: $obsidianInboxFolder)
                    .help("Ordner für neue Notizen")
                TextField("datei1.md, datei2.md, …", text: $knownObsidianFiles)
                Text("Bekannte Dateinamen, damit Claude bestehende Notizen ergänzen kann.")
                    .font(.caption).foregroundColor(.secondary)
            } header: { Text("Obsidian") }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }

    // MARK: - Aktionen

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
