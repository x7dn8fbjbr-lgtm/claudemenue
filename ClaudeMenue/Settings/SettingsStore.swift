import Foundation
import Security

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let anthropicTag: String
    private let todoistTag: String
    private let service = "de.hoeferconsulting.ClaudeMenue"

    init(keychainPrefix: String = "de.hoeferconsulting.ClaudeMenue") {
        anthropicTag = "\(keychainPrefix).anthropicKey"
        todoistTag = "\(keychainPrefix).todoistToken"
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
