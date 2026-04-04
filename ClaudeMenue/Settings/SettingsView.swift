import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClaudeMenue — Einstellungen"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }
}

struct SettingsView: View {
    @State private var anthropicKey: String = SettingsStore.shared.anthropicApiKey ?? ""
    @State private var todoistToken: String = SettingsStore.shared.todoistApiToken ?? ""
    @State private var savedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Claude API Key")
                    .font(.headline)
                SecureField("sk-ant-…", text: $anthropicKey)
                    .textFieldStyle(.roundedBorder)
                Text("Erstellen unter console.anthropic.com → API Keys")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Group {
                Text("Todoist API Token")
                    .font(.headline)
                SecureField("Token…", text: $todoistToken)
                    .textFieldStyle(.roundedBorder)
                Text("Zu finden unter todoist.com → Einstellungen → Integrationen → API Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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
        }
        .onAppear {
            anthropicKey = SettingsStore.shared.anthropicApiKey ?? ""
            todoistToken = SettingsStore.shared.todoistApiToken ?? ""
        }
        .padding(24)
        .frame(width: 460)
    }

    private func save() {
        SettingsStore.shared.anthropicApiKey = anthropicKey.isEmpty ? nil : anthropicKey
        SettingsStore.shared.todoistApiToken = todoistToken.isEmpty ? nil : todoistToken
        savedFeedback = true
        NotificationCenter.default.post(name: .claudeMenueSettingsSaved, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedFeedback = false }
    }
}

extension NSNotification.Name {
    static let claudeMenueSettingsSaved = NSNotification.Name("de.hoeferconsulting.ClaudeMenue.settingsSaved")
}
