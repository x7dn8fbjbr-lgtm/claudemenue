import Foundation
import Security

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let anthropicTag: String
    private let todoistTag: String
    private let service = "de.hoeferconsulting.ClaudeMenue"
    private let defaults = UserDefaults.standard

    init(keychainPrefix: String = "de.hoeferconsulting.ClaudeMenue") {
        anthropicTag = "\(keychainPrefix).anthropicKey"
        todoistTag = "\(keychainPrefix).todoistToken"
    }

    // MARK: - Persönlicher Kontext (UserDefaults)

    var userName: String {
        get { defaults.string(forKey: "userName") ?? "" }
        set { defaults.set(newValue, forKey: "userName") }
    }

    var projectContext: String {
        get { defaults.string(forKey: "projectContext") ?? "" }
        set { defaults.set(newValue, forKey: "projectContext") }
    }

    var obsidianVaultPath: String {
        get { defaults.string(forKey: "obsidianVaultPath") ?? "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault" }
        set { defaults.set(newValue, forKey: "obsidianVaultPath") }
    }

    var knownObsidianFiles: String {
        get { defaults.string(forKey: "knownObsidianFiles") ?? "" }
        set { defaults.set(newValue, forKey: "knownObsidianFiles") }
    }

    var obsidianInboxFolder: String {
        get { defaults.string(forKey: "obsidianInboxFolder") ?? "00_INBOX" }
        set { defaults.set(newValue, forKey: "obsidianInboxFolder") }
    }

    var obsidianVaultURL: URL {
        let raw = obsidianVaultPath.replacingOccurrences(of: "~", with: NSHomeDirectory())
        return URL(fileURLWithPath: raw)
    }

    var anthropicApiKey: String? {
        get { load(tag: anthropicTag) }
        set { newValue == nil ? delete(tag: anthropicTag) : save(tag: anthropicTag, value: newValue!) }
    }

    var todoistApiToken: String? {
        get { load(tag: todoistTag) }
        set { newValue == nil ? delete(tag: todoistTag) : save(tag: todoistTag, value: newValue!) }
    }

    var isConfigured: Bool {
        anthropicApiKey != nil && todoistApiToken != nil
    }

    private func save(tag: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(tag: tag)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tag,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            assertionFailure("Keychain save failed for \(tag): \(status)")
        }
    }

    private func load(tag: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(tag: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tag
        ]
        SecItemDelete(query as CFDictionary)
    }
}
