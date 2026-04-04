import XCTest
@testable import ClaudeMenue

final class SettingsStoreTests: XCTestCase {
    // Separate store with test prefix to avoid overwriting real keys
    var store: SettingsStore!

    override func setUp() {
        store = SettingsStore(keychainPrefix: "de.hoeferconsulting.ClaudeMenue.test")
        store.anthropicApiKey = nil
        store.todoistApiToken = nil
    }

    override func tearDown() {
        store.anthropicApiKey = nil
        store.todoistApiToken = nil
    }

    func test_anthropicApiKey_saveAndLoad() {
        store.anthropicApiKey = "sk-ant-testkey"
        XCTAssertEqual(store.anthropicApiKey, "sk-ant-testkey")
    }

    func test_todoistApiToken_saveAndLoad() {
        store.todoistApiToken = "todoist-secret-token"
        XCTAssertEqual(store.todoistApiToken, "todoist-secret-token")
    }

    func test_deleteKey_returnsNil() {
        store.anthropicApiKey = "some-key"
        store.anthropicApiKey = nil
        XCTAssertNil(store.anthropicApiKey)
    }

    func test_isConfigured_falseWhenEmpty() {
        XCTAssertFalse(store.isConfigured)
    }

    func test_isConfigured_trueWhenBothKeysSet() {
        store.anthropicApiKey = "key1"
        store.todoistApiToken = "key2"
        XCTAssertTrue(store.isConfigured)
    }
}
