# ClaudeMenue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS-Menüleisten-App in Swift/SwiftUI, die Texteingaben per Claude Function Calling autonom in Todoist-Tasks und Obsidian-Notizen umwandelt.

**Architecture:** NSStatusItem-App (kein Dock-Icon) mit schwebendem NSPanel-Eingabefenster. ClaudeService sendet Eingabe + eingebettetes Projektprofil an Anthropic API mit Tool Use; die zurückgelieferten Tool-Calls werden von TodoistService (REST API) und ObsidianService (Dateisystem) ausgeführt. Ergebnis als macOS-Notification.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, XCTest, URLSession async/await, Security.framework (Keychain), UserNotifications.framework

---

## Dateistruktur

```
ClaudeMenue/
├── ClaudeMenue.xcodeproj/
├── ClaudeMenue/
│   ├── App/
│   │   └── ClaudeMenueApp.swift          ← @main + AppDelegate, Verdrahtung aller Komponenten
│   ├── Models/
│   │   ├── AnthropicModels.swift          ← Codable-Typen für Anthropic API Request/Response
│   │   └── ToolCall.swift                 ← ToolCallAction-Enum + ContentBlock-Extension
│   ├── Services/
│   │   ├── ClaudeService.swift            ← Anthropic API, Function Calling, Tool-Dispatch
│   │   ├── TodoistService.swift           ← Todoist REST API
│   │   ├── ObsidianService.swift          ← Dateisystem-Operationen
│   │   └── NotificationService.swift      ← UNUserNotificationCenter
│   ├── Settings/
│   │   ├── SettingsStore.swift            ← Keychain-Wrapper
│   │   └── SettingsView.swift             ← Settings-Fenster (SwiftUI + NSWindowController)
│   └── Window/
│       ├── InputWindowController.swift    ← NSPanel-Lifecycle
│       └── InputView.swift                ← SwiftUI-Eingabeformular
├── ClaudeMenue/Resources/
│   ├── Info.plist
│   └── ClaudeMenue.entitlements
└── ClaudeMenueTests/
    ├── AnthropicModelsTests.swift
    ├── SettingsStoreTests.swift
    ├── ObsidianServiceTests.swift
    ├── TodoistServiceTests.swift
    └── ClaudeServiceTests.swift
```

---

## Task 1: Xcode-Projekt anlegen

**Files:**
- Create: `ClaudeMenue.xcodeproj/` (via Xcode GUI)
- Create: `ClaudeMenue/Resources/Info.plist`
- Create: `ClaudeMenue/Resources/ClaudeMenue.entitlements`

- [ ] **Step 1: Neues Xcode-Projekt anlegen**

  Xcode öffnen → File → New → Project → macOS → App
  - Product Name: `ClaudeMenue`
  - Bundle Identifier: `de.hoeferconsulting.ClaudeMenue`
  - Language: Swift
  - Interface: SwiftUI
  - Include Tests: ✓
  - Deployment Target: macOS 14.0

- [ ] **Step 2: Verzeichnisstruktur anlegen**

```bash
cd /Users/detlefhoefer/Claude/Privat/claudemenue
mkdir -p ClaudeMenue/App ClaudeMenue/Models ClaudeMenue/Services ClaudeMenue/Settings ClaudeMenue/Window ClaudeMenue/Resources
mkdir -p ClaudeMenueTests
```

- [ ] **Step 3: Info.plist erstellen**

  Datei `ClaudeMenue/Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ClaudeMenue</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
```

  > `LSUIElement = true` sorgt dafür, dass die App KEIN Dock-Icon zeigt.

- [ ] **Step 4: Entitlements erstellen**

  Datei `ClaudeMenue/Resources/ClaudeMenue.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Build Settings in Xcode anpassen**

  In Xcode → Target ClaudeMenue → Build Settings:
  - `INFOPLIST_FILE` = `ClaudeMenue/Resources/Info.plist`
  - `CODE_SIGN_ENTITLEMENTS` = `ClaudeMenue/Resources/ClaudeMenue.entitlements`

- [ ] **Step 6: Commit**

```bash
git init
git add .
git commit -m "chore: Xcode-Projekt anlegen, Info.plist, Entitlements"
```

---

## Task 2: AnthropicModels.swift + ToolCall.swift

**Files:**
- Create: `ClaudeMenue/Models/AnthropicModels.swift`
- Create: `ClaudeMenue/Models/ToolCall.swift`
- Create: `ClaudeMenueTests/AnthropicModelsTests.swift`

- [ ] **Step 1: Testdatei anlegen und ersten Test schreiben**

  Datei `ClaudeMenueTests/AnthropicModelsTests.swift`:
```swift
import XCTest
@testable import ClaudeMenue

final class AnthropicModelsTests: XCTestCase {
    
    // Test: AnthropicRequest wird korrekt zu JSON encodiert
    func test_anthropicRequest_encodesMaxTokensAsSnakeCase() throws {
        let request = AnthropicRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            system: "system",
            messages: [AnthropicMessage(role: "user", content: "Hallo")],
            tools: []
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["max_tokens"] as? Int, 1024)
        XCTAssertNil(json["maxTokens"])
    }
    
    // Test: AnthropicResponse mit tool_use ContentBlock wird korrekt decodiert
    func test_anthropicResponse_decodesToolUseBlock() throws {
        let json = """
        {
            "id": "msg_123",
            "type": "message",
            "role": "assistant",
            "content": [{
                "type": "tool_use",
                "id": "tool_abc",
                "name": "create_todoist_task",
                "input": { "title": "Zahnarzt anrufen" }
            }],
            "stop_reason": "tool_use"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: json)
        XCTAssertEqual(response.stopReason, "tool_use")
        XCTAssertEqual(response.content.first?.type, "tool_use")
        XCTAssertEqual(response.content.first?.name, "create_todoist_task")
        XCTAssertEqual(response.content.first?.input?["title"]?.stringValue, "Zahnarzt anrufen")
    }
    
    // Test: ContentBlock.toToolCallAction() gibt .createTodoistTask zurück
    func test_contentBlock_parsesToCreateTodoistTask() throws {
        let json = """
        {
            "type": "tool_use",
            "id": "t1",
            "name": "create_todoist_task",
            "input": { "title": "Einkaufen", "due_date": "morgen" }
        }
        """.data(using: .utf8)!
        
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .createTodoistTask(let title, _, _, let dueDate) = block.toToolCallAction() else {
            XCTFail("Erwartet .createTodoistTask")
            return
        }
        XCTAssertEqual(title, "Einkaufen")
        XCTAssertEqual(dueDate, "morgen")
    }
    
    // Test: ContentBlock.toToolCallAction() gibt .createObsidianNote zurück
    func test_contentBlock_parsesToCreateObsidianNote() throws {
        let json = """
        {
            "type": "tool_use",
            "id": "t2",
            "name": "create_obsidian_note",
            "input": { "filename": "idee-neues-projekt", "content": "# Idee\\nDetails hier" }
        }
        """.data(using: .utf8)!
        
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .createObsidianNote(let filename, let content, _) = block.toToolCallAction() else {
            XCTFail("Erwartet .createObsidianNote")
            return
        }
        XCTAssertEqual(filename, "idee-neues-projekt")
        XCTAssertTrue(content.contains("Idee"))
    }
    
    // Test: ContentBlock mit unbekanntem Tool-Namen gibt nil zurück
    func test_contentBlock_unknownToolReturnsNil() throws {
        let json = """
        { "type": "tool_use", "id": "t3", "name": "unknown_tool", "input": {} }
        """.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        XCTAssertNil(block.toToolCallAction())
    }
}
```

- [ ] **Step 2: Tests ausführen — müssen FAIL sein**

  In Xcode: ⌘U ausführen. Erwartetes Ergebnis: Compilerfehler "AnthropicRequest not found".

- [ ] **Step 3: AnthropicModels.swift implementieren**

  Datei `ClaudeMenue/Models/AnthropicModels.swift`:
```swift
import Foundation

// MARK: - Request

struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]
    
    enum CodingKeys: String, CodingKey {
        case model, system, messages, tools
        case maxTokens = "max_tokens"
    }
}

struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

struct AnthropicTool: Encodable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct ToolInputSchema: Encodable {
    let type: String = "object"
    let properties: [String: ToolProperty]
    let required: [String]
}

struct ToolProperty: Encodable {
    let type: String
    let description: String
}

// MARK: - Response

struct AnthropicResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let stopReason: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content
        case stopReason = "stop_reason"
    }
}

struct ContentBlock: Decodable {
    let type: String
    let id: String?
    let name: String?
    let input: [String: JSONValue]?
    let text: String?
}

// MARK: - JSONValue (für beliebige Tool-Input-Werte)

enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let i = try? container.decode(Int.self) { self = .int(i); return }
        if let d = try? container.decode(Double.self) { self = .double(d); return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if container.decodeNil() { self = .null; return }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Nicht unterstützter Typ")
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
    
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}
```

- [ ] **Step 4: ToolCall.swift implementieren**

  Datei `ClaudeMenue/Models/ToolCall.swift`:
```swift
import Foundation

enum ToolCallAction {
    case createTodoistTask(title: String, description: String?, project: String?, dueDate: String?)
    case createObsidianNote(filename: String, content: String, folder: String?)
    case updateObsidianNote(filename: String, contentToAppend: String)
}

extension ContentBlock {
    func toToolCallAction() -> ToolCallAction? {
        guard type == "tool_use", let name = name, let input = input else { return nil }
        
        switch name {
        case "create_todoist_task":
            guard let title = input["title"]?.stringValue else { return nil }
            return .createTodoistTask(
                title: title,
                description: input["description"]?.stringValue,
                project: input["project"]?.stringValue,
                dueDate: input["due_date"]?.stringValue
            )
        case "create_obsidian_note":
            guard let filename = input["filename"]?.stringValue,
                  let content = input["content"]?.stringValue else { return nil }
            return .createObsidianNote(
                filename: filename,
                content: content,
                folder: input["folder"]?.stringValue
            )
        case "update_obsidian_note":
            guard let filename = input["filename"]?.stringValue,
                  let contentToAppend = input["content_to_append"]?.stringValue else { return nil }
            return .updateObsidianNote(filename: filename, contentToAppend: contentToAppend)
        default:
            return nil
        }
    }
}
```

- [ ] **Step 5: Tests ausführen — müssen PASS sein**

  ⌘U. Erwartet: 4 Tests grün.

- [ ] **Step 6: Commit**

```bash
git add ClaudeMenue/Models/ ClaudeMenueTests/AnthropicModelsTests.swift
git commit -m "feat: AnthropicModels + ToolCall mit JSON-Tests"
```

---

## Task 3: SettingsStore.swift

**Files:**
- Create: `ClaudeMenue/Settings/SettingsStore.swift`
- Create: `ClaudeMenueTests/SettingsStoreTests.swift`

- [ ] **Step 1: Test schreiben**

  Datei `ClaudeMenueTests/SettingsStoreTests.swift`:
```swift
import XCTest
@testable import ClaudeMenue

final class SettingsStoreTests: XCTestCase {
    // Separater Store mit Test-Tags, damit echte Keys nicht überschrieben werden
    var store: SettingsStore!
    
    override func setUp() {
        store = SettingsStore(keychainPrefix: "de.hoeferconsulting.ClaudeMenue.test")
        // Aufräumen vor jedem Test
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
```

- [ ] **Step 3: Tests ausführen — müssen FAIL sein (TodoistService not found)**

- [ ] **Step 3: SettingsStore.swift implementieren**

  Datei `ClaudeMenue/Settings/SettingsStore.swift`:
```swift
import Foundation
import Security

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    private let anthropicTag: String
    private let todoistTag: String
    
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
            kSecAttrAccount as String: tag,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func load(tag: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
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
            kSecAttrAccount as String: tag
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Tests ausführen — müssen PASS sein**

  ⌘U. Erwartet: 5 Tests grün.

- [ ] **Step 5: Commit**

```bash
git add ClaudeMenue/Settings/SettingsStore.swift ClaudeMenueTests/SettingsStoreTests.swift
git commit -m "feat: SettingsStore mit Keychain-Persistenz"
```

---

## Task 4: NotificationService.swift

**Files:**
- Create: `ClaudeMenue/Services/NotificationService.swift`

  > NotificationService hat keine sinnvollen Unit-Tests (UNUserNotificationCenter kann nicht ohne UI-Kontext getestet werden). Wir implementieren direkt.

- [ ] **Step 1: NotificationService.swift implementieren**

  Datei `ClaudeMenue/Services/NotificationService.swift`:
```swift
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification-Berechtigung Fehler: \(error)")
            }
        }
    }
    
    func send(title: String, body: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let body = body, !body.isEmpty {
            content.body = body
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // sofort
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification-Fehler: \(error)")
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ClaudeMenue/Services/NotificationService.swift
git commit -m "feat: NotificationService"
```

---

## Task 5: ObsidianService.swift

**Files:**
- Create: `ClaudeMenue/Services/ObsidianService.swift`
- Create: `ClaudeMenueTests/ObsidianServiceTests.swift`

- [ ] **Step 1: Test schreiben**

  Datei `ClaudeMenueTests/ObsidianServiceTests.swift`:
```swift
import XCTest
@testable import ClaudeMenue

final class ObsidianServiceTests: XCTestCase {
    var tempDir: URL!
    var service: ObsidianService!
    
    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = ObsidianService(vaultPath: tempDir)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func test_createNote_schreibtDateiInInbox() throws {
        try service.createNote(filename: "test-notiz", content: "# Test\nInhalt")
        
        let fileURL = tempDir.appendingPathComponent("00_INBOX/test-notiz.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(content, "# Test\nInhalt")
    }
    
    func test_createNote_haengtMdAnWennFehlt() throws {
        try service.createNote(filename: "ohne-endung", content: "Inhalt")
        let fileURL = tempDir.appendingPathComponent("00_INBOX/ohne-endung.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func test_createNote_benutztBenutzerdefiniertordner() throws {
        try service.createNote(filename: "notiz", content: "Inhalt", folder: "10_Projects")
        let fileURL = tempDir.appendingPathComponent("10_Projects/notiz.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func test_updateNote_haengtTextAn() throws {
        // Erst Datei erstellen
        let fileURL = tempDir.appendingPathComponent("00_INBOX/vorhandene.md")
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("00_INBOX"),
            withIntermediateDirectories: true
        )
        try "# Bestehend\nAlt".write(to: fileURL, atomically: true, encoding: .utf8)
        
        try service.updateNote(filename: "vorhandene.md", contentToAppend: "Neu hinzugefügt")
        
        let result = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(result.contains("Alt"))
        XCTAssertTrue(result.contains("Neu hinzugefügt"))
    }
    
    func test_updateNote_wirftFehlerWennDateiNichtExistiert() {
        XCTAssertThrowsError(try service.updateNote(filename: "nicht-vorhanden.md", contentToAppend: "Text")) { error in
            XCTAssertTrue(error is ObsidianService.ObsidianError)
        }
    }
}
```

- [ ] **Step 2: Tests ausführen — müssen FAIL sein**

- [ ] **Step 3: ObsidianService.swift implementieren**

  Datei `ClaudeMenue/Services/ObsidianService.swift`:
```swift
import Foundation

class ObsidianService {
    let vaultPath: URL
    
    init(vaultPath: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/iCloud~md~obsidian/Documents/mylife")) {
        self.vaultPath = vaultPath
    }
    
    func createNote(filename: String, content: String, folder: String = "00_INBOX") throws {
        let sanitizedName = filename.hasSuffix(".md") ? filename : "\(filename).md"
        let folderURL = vaultPath.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let fileURL = folderURL.appendingPathComponent(sanitizedName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func updateNote(filename: String, contentToAppend: String) throws {
        let sanitizedName = filename.hasSuffix(".md") ? filename : "\(filename).md"
        let fileURL = try findFile(named: sanitizedName)
        let existing = try String(contentsOf: fileURL, encoding: .utf8)
        let updated = existing + "\n\n" + contentToAppend
        try updated.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func findFile(named filename: String) throws -> URL {
        guard let enumerator = FileManager.default.enumerator(at: vaultPath, includingPropertiesForKeys: nil) else {
            throw ObsidianError.fileNotFound(filename)
        }
        for case let url as URL in enumerator {
            if url.lastPathComponent == filename { return url }
        }
        throw ObsidianError.fileNotFound(filename)
    }
    
    enum ObsidianError: LocalizedError {
        case fileNotFound(String)
        var errorDescription: String? {
            if case .fileNotFound(let name) = self {
                return "Datei '\(name)' nicht im Obsidian Vault gefunden"
            }
            return nil
        }
    }
}
```

- [ ] **Step 4: Tests ausführen — müssen PASS sein**

  ⌘U. Erwartet: 5 Tests grün.

- [ ] **Step 5: Commit**

```bash
git add ClaudeMenue/Services/ObsidianService.swift ClaudeMenueTests/ObsidianServiceTests.swift
git commit -m "feat: ObsidianService mit Dateisystem-Tests"
```

---

## Task 6: TodoistService.swift

**Files:**
- Create: `ClaudeMenue/Services/TodoistService.swift`
- Create: `ClaudeMenueTests/TodoistServiceTests.swift`

- [ ] **Step 1: Gemeinsame Test-Hilfsdatei anlegen**

  Datei `ClaudeMenueTests/TestHelpers.swift`:
```swift
import XCTest
@testable import ClaudeMenue

// MARK: - MockURLSession (geteilt von TodoistServiceTests + ClaudeServiceTests)

class MockURLSession: URLSessionProtocol {
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var lastRequest: URLRequest?
    var errorToThrow: Error?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = errorToThrow { throw error }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: responseStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}
```

- [ ] **Step 2: Test schreiben**

  Datei `ClaudeMenueTests/TodoistServiceTests.swift`:
```swift
import XCTest
@testable import ClaudeMenue

final class TodoistServiceTests: XCTestCase {
    
    func test_createTask_sendetKorrektesJSON() async throws {
        let mockSession = MockURLSession()
        mockSession.responseData = "{}".data(using: .utf8)!
        mockSession.responseStatusCode = 200
        
        let service = TodoistService(token: "test-token", session: mockSession)
        try await service.createTask(title: "Zahnarzt anrufen", description: "Dringend", dueDate: "morgen")
        
        let request = try XCTUnwrap(mockSession.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
        XCTAssertEqual(body["content"], "Zahnarzt anrufen")
        XCTAssertEqual(body["description"], "Dringend")
        XCTAssertEqual(body["due_string"], "morgen")
    }
    
    func test_createTask_wirdThrowBeiFehler() async {
        let mockSession = MockURLSession()
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 401
        
        let service = TodoistService(token: "bad-token", session: mockSession)
        
        do {
            try await service.createTask(title: "Test")
            XCTFail("Sollte Fehler werfen")
        } catch {
            XCTAssertTrue(error is TodoistService.TodoistError)
        }
    }
}

// MARK: - Mock

class MockURLSession: URLSessionProtocol {
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var lastRequest: URLRequest?
    var errorToThrow: Error?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = errorToThrow { throw error }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: responseStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}
```

- [ ] **Step 2: Tests ausführen — müssen FAIL sein**

- [ ] **Step 4: TodoistService.swift implementieren**

  Datei `ClaudeMenue/Services/TodoistService.swift`:
```swift
import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

class TodoistService {
    private let session: URLSessionProtocol
    private let baseURL = URL(string: "https://api.todoist.com/rest/v2")!
    private let token: String
    
    init(token: String, session: URLSessionProtocol = URLSession.shared) {
        self.token = token
        self.session = session
    }
    
    func createTask(
        title: String,
        description: String? = nil,
        project: String? = nil,
        dueDate: String? = nil
    ) async throws {
        var body: [String: String] = ["content": title]
        if let description = description, !description.isEmpty { body["description"] = description }
        if let dueDate = dueDate, !dueDate.isEmpty { body["due_string"] = dueDate }
        // Projekt-Lookup by Name würde extra API-Call erfordern; in v1 ignoriert
        
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TodoistError.requestFailed
        }
    }
    
    enum TodoistError: LocalizedError {
        case requestFailed
        var errorDescription: String? { "Todoist-Task konnte nicht erstellt werden" }
    }
}
```

- [ ] **Step 5: Tests ausführen — müssen PASS sein**

  ⌘U. Erwartet: 2 Tests grün.

- [ ] **Step 6: Commit**

```bash
git add ClaudeMenue/Services/TodoistService.swift ClaudeMenueTests/TodoistServiceTests.swift ClaudeMenueTests/TestHelpers.swift
git commit -m "feat: TodoistService mit Mock-URLSession-Tests"
```

---

## Task 7: ClaudeService.swift

**Files:**
- Create: `ClaudeMenue/Services/ClaudeService.swift`
- Create: `ClaudeMenueTests/ClaudeServiceTests.swift`

- [ ] **Step 1: Test schreiben**

  Datei `ClaudeMenueTests/ClaudeServiceTests.swift`:
```swift
import XCTest
@testable import ClaudeMenue

final class ClaudeServiceTests: XCTestCase {
    
    // Test: process() ruft Todoist-Service auf bei Tool-Call create_todoist_task
    func test_process_ruftTodoistBeiTaskAuf() async throws {
        let mockSession = MockURLSession()
        let anthropicJSON = """
        {
            "id": "msg_1", "type": "message", "role": "assistant",
            "content": [{
                "type": "tool_use", "id": "t1",
                "name": "create_todoist_task",
                "input": { "title": "Testaufgabe" }
            }],
            "stop_reason": "tool_use"
        }
        """.data(using: .utf8)!
        mockSession.responseData = anthropicJSON
        mockSession.responseStatusCode = 200
        
        let todoistMock = MockTodoistService()
        let obsidianService = ObsidianService(vaultPath: FileManager.default.temporaryDirectory)
        let notificationService = SpyNotificationService()
        
        let service = ClaudeService(
            apiKey: "test-key",
            obsidianService: obsidianService,
            todoistService: todoistMock,
            notificationService: notificationService,
            session: mockSession
        )
        
        await service.process(input: "Erinnere mich: Testaufgabe")
        
        XCTAssertEqual(todoistMock.createdTaskTitle, "Testaufgabe")
        XCTAssertTrue(notificationService.sentTitles.contains("Todoist-Task erstellt"))
    }
    
    // Test: process() sendet Fehler-Notification bei API-Fehler
    func test_process_sendetFehlerNotificationBeiAPIFehler() async {
        let mockSession = MockURLSession()
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 500
        
        let notificationService = SpyNotificationService()
        let todoistMock = MockTodoistService()
        let obsidianService = ObsidianService(vaultPath: FileManager.default.temporaryDirectory)
        
        let service = ClaudeService(
            apiKey: "test-key",
            obsidianService: obsidianService,
            todoistService: todoistMock,
            notificationService: notificationService,
            session: mockSession
        )
        
        await service.process(input: "Irgendwas")
        
        XCTAssertTrue(notificationService.sentTitles.contains("Fehler beim Senden an Claude"))
    }
}

// MARK: - Mocks für ClaudeServiceTests
// MockURLSession ist in TestHelpers.swift definiert (shared)

class MockTodoistService: TodoistService {
    var createdTaskTitle: String?
    
    init() { super.init(token: "mock") }
    
    override func createTask(title: String, description: String?, project: String?, dueDate: String?) async throws {
        createdTaskTitle = title
    }
}

class SpyNotificationService: NotificationService {
    var sentTitles: [String] = []
    
    override func send(title: String, body: String? = nil) {
        sentTitles.append(title)
    }
}
```

- [ ] **Step 2: Tests ausführen — müssen FAIL sein**

- [ ] **Step 3: ClaudeService.swift implementieren**

  Datei `ClaudeMenue/Services/ClaudeService.swift`:
```swift
import Foundation

class ClaudeService {
    private let session: URLSessionProtocol
    private let apiKey: String
    let obsidianService: ObsidianService
    let todoistService: TodoistService
    let notificationService: NotificationService
    
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"
    
    private let systemPrompt = """
    Du bist der persönliche Assistent von Detlef Hoefer.
    Detlef schickt dir kurze Gedanken, Ideen oder Aufgaben.
    Du entscheidest autonom, was damit zu tun ist, und rufst die passenden Tools auf.
    Antworte NICHT mit Text — ausschließlich mit Tool-Calls.
    
    Projekte von Detlef:
    - Beruf/Consulting: Hoefer Consulting, DB InfraGO (FSQ IT, FBQ, BahnGPT)
    - Privat: Wärmepumpe & PV, Familiengeschichte, Stammbaum, Finanzen/Steuer, Arztsuche
    - Obsidian Vault: ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/mylife/
    - Neue Notizen immer in: 00_INBOX/
    - Bekannte Dateinamen für update_obsidian_note: waermepumpe-solar.md, familienarchiv.md, finanzen.md, familie.md
    """
    
    private var tools: [AnthropicTool] {
        [
            AnthropicTool(
                name: "create_todoist_task",
                description: "Erstellt eine neue Aufgabe in Todoist",
                inputSchema: ToolInputSchema(
                    properties: [
                        "title": ToolProperty(type: "string", description: "Titel der Aufgabe"),
                        "description": ToolProperty(type: "string", description: "Optionale Beschreibung"),
                        "project": ToolProperty(type: "string", description: "Projektname (optional)"),
                        "due_date": ToolProperty(type: "string", description: "Fälligkeitsdatum, z.B. 'morgen' oder '2026-04-10'")
                    ],
                    required: ["title"]
                )
            ),
            AnthropicTool(
                name: "create_obsidian_note",
                description: "Erstellt eine neue Markdown-Notiz in Obsidian (00_INBOX)",
                inputSchema: ToolInputSchema(
                    properties: [
                        "filename": ToolProperty(type: "string", description: "Dateiname ohne .md"),
                        "content": ToolProperty(type: "string", description: "Inhalt als Markdown"),
                        "folder": ToolProperty(type: "string", description: "Zielordner, Standard: 00_INBOX")
                    ],
                    required: ["filename", "content"]
                )
            ),
            AnthropicTool(
                name: "update_obsidian_note",
                description: "Ergänzt eine bestehende Obsidian-Notiz am Ende",
                inputSchema: ToolInputSchema(
                    properties: [
                        "filename": ToolProperty(type: "string", description: "Dateiname inkl. .md"),
                        "content_to_append": ToolProperty(type: "string", description: "Anzuhängender Text")
                    ],
                    required: ["filename", "content_to_append"]
                )
            )
        ]
    }
    
    init(
        apiKey: String,
        obsidianService: ObsidianService = ObsidianService(),
        todoistService: TodoistService,
        notificationService: NotificationService = NotificationService.shared,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.apiKey = apiKey
        self.obsidianService = obsidianService
        self.todoistService = todoistService
        self.notificationService = notificationService
        self.session = session
    }
    
    func process(input: String, onLoadingChange: ((Bool) -> Void)? = nil) async {
        onLoadingChange?(true)
        defer { onLoadingChange?(false) }
        
        do {
            let actions = try await fetchToolCalls(for: input)
            guard !actions.isEmpty else {
                notificationService.send(title: "Keine Aktion erkannt")
                return
            }
            for action in actions {
                try await execute(action: action)
            }
        } catch {
            notificationService.send(title: "Fehler beim Senden an Claude", body: error.localizedDescription)
        }
    }
    
    private func fetchToolCalls(for input: String) async throws -> [ToolCallAction] {
        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: 1024,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: input)],
            tools: tools
        )
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClaudeError.apiError
        }
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return decoded.content.compactMap { $0.toToolCallAction() }
    }
    
    private func execute(action: ToolCallAction) async throws {
        switch action {
        case .createTodoistTask(let title, let description, let project, let dueDate):
            try await todoistService.createTask(title: title, description: description, project: project, dueDate: dueDate)
            notificationService.send(title: "Todoist-Task erstellt", body: title)
            
        case .createObsidianNote(let filename, let content, let folder):
            try obsidianService.createNote(filename: filename, content: content, folder: folder ?? "00_INBOX")
            notificationService.send(title: "Obsidian-Notiz erstellt", body: filename)
            
        case .updateObsidianNote(let filename, let contentToAppend):
            do {
                try obsidianService.updateNote(filename: filename, contentToAppend: contentToAppend)
                notificationService.send(title: "Obsidian-Notiz aktualisiert", body: filename)
            } catch ObsidianService.ObsidianError.fileNotFound {
                // Fallback: neue Notiz anlegen
                try obsidianService.createNote(filename: filename, content: contentToAppend)
                notificationService.send(title: "Obsidian-Notiz erstellt", body: "\(filename) (neu)")
            }
        }
    }
    
    enum ClaudeError: LocalizedError {
        case apiError
        var errorDescription: String? { "Fehler beim Senden an Claude" }
    }
}
```

- [ ] **Step 4: Tests ausführen — müssen PASS sein**

  ⌘U. Erwartet: 2 Tests grün.

- [ ] **Step 5: Commit**

```bash
git add ClaudeMenue/Services/ClaudeService.swift ClaudeMenueTests/ClaudeServiceTests.swift
git commit -m "feat: ClaudeService mit Function Calling und Tests"
```

---

## Task 8: InputView.swift

**Files:**
- Create: `ClaudeMenue/Window/InputView.swift`

  > SwiftUI-Views haben keine sinnvollen Unit-Tests ohne UI-Testing-Framework. Wir implementieren direkt und testen manuell.

- [ ] **Step 1: InputView.swift implementieren**

  Datei `ClaudeMenue/Window/InputView.swift`:
```swift
import SwiftUI

struct InputView: View {
    @State private var text = ""
    @State private var isLoading = false
    
    var onSubmit: (String) async -> Void
    var onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $text)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 120, maxHeight: 300)
                .disabled(isLoading)
                .onAppear { DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) } }
            
            Divider().background(Color.gray.opacity(0.3))
            
            HStack(spacing: 8) {
                Text(isLoading ? "Claude denkt…" : "⌘↩ Senden · Esc Schließen")
                    .font(.caption)
                    .foregroundColor(Color.gray)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Button("Senden") {
                        Task { await submit() }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
        .cornerRadius(12)
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
    
    private func submit() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        await onSubmit(trimmed)
        isLoading = false
        text = ""
        onClose()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ClaudeMenue/Window/InputView.swift
git commit -m "feat: InputView SwiftUI mit Markdown-Textfeld und Ladeindikator"
```

---

## Task 9: InputWindowController.swift

**Files:**
- Create: `ClaudeMenue/Window/InputWindowController.swift`

- [ ] **Step 1: InputWindowController.swift implementieren**

  Datei `ClaudeMenue/Window/InputWindowController.swift`:
```swift
import AppKit
import SwiftUI

class InputWindowController: NSWindowController {
    var onSubmit: ((String) async -> Void)?
    
    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: panel)
        
        // Schließen bei Klick außerhalb
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func showCentered() {
        let inputView = InputView(
            onSubmit: { [weak self] text in
                await self?.onSubmit?(text)
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        window?.contentView = NSHostingView(rootView: inputView)
        
        guard let screen = NSScreen.main, let window = window else { return }
        let x = screen.visibleFrame.midX - window.frame.width / 2
        let y = screen.visibleFrame.midY - window.frame.height / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func windowDidResignKey() {
        close()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ClaudeMenue/Window/InputWindowController.swift
git commit -m "feat: InputWindowController als schwebendes NSPanel"
```

---

## Task 10: MenuBarManager.swift + HotKeyManager.swift

**Files:**
- Create: `ClaudeMenue/App/MenuBarManager.swift`
- Create: `ClaudeMenue/App/HotKeyManager.swift`

- [ ] **Step 1: MenuBarManager.swift implementieren**

  Datei `ClaudeMenue/App/MenuBarManager.swift`:
```swift
import AppKit

class MenuBarManager {
    private var statusItem: NSStatusItem?
    private let windowController: InputWindowController
    weak var settingsWindowController: SettingsWindowController?
    
    init(windowController: InputWindowController) {
        self.windowController = windowController
    }
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(loading: false)
        
        guard let button = statusItem?.button else { return }
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    func setLoading(_ loading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.setIcon(loading: loading)
        }
    }
    
    private func setIcon(loading: Bool) {
        let symbolName = loading ? "ellipsis.circle" : "bubble.left.and.text.bubble.right"
        statusItem?.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ClaudeMenue")
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWindow()
        }
    }
    
    private func toggleWindow() {
        if windowController.window?.isVisible == true {
            windowController.close()
        } else {
            windowController.showCentered()
        }
    }
    
    private func showMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Einstellungen…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Beenden", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.popUpMenu(menu)
    }
    
    @objc private func openSettings() {
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 2: HotKeyManager.swift implementieren**

  Datei `ClaudeMenue/App/HotKeyManager.swift`:
```swift
import AppKit

class HotKeyManager {
    private var monitor: Any?
    var onHotKey: (() -> Void)?
    
    /// Startet den globalen Key-Monitor. Benötigt Accessibility-Berechtigung.
    func start() {
        // Accessibility-Berechtigung anfordern (zeigt System-Dialog wenn nötig)
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        // ⌘⇧Space: keyCode 49 = Space
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 49,
                  event.modifierFlags.contains(.command),
                  event.modifierFlags.contains(.shift) else { return }
            DispatchQueue.main.async { self?.onHotKey?() }
        }
    }
    
    func stop() {
        guard let monitor = monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
    
    deinit { stop() }
}
```

- [ ] **Step 3: Commit**

```bash
git add ClaudeMenue/App/MenuBarManager.swift ClaudeMenue/App/HotKeyManager.swift
git commit -m "feat: MenuBarManager (NSStatusItem) + HotKeyManager (⌘⇧Space)"
```

---

## Task 11: SettingsView.swift

**Files:**
- Create: `ClaudeMenue/Settings/SettingsView.swift`

- [ ] **Step 1: SettingsView.swift implementieren**

  Datei `ClaudeMenue/Settings/SettingsView.swift`:
```swift
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
        .padding(24)
        .frame(width: 460)
    }
    
    private func save() {
        SettingsStore.shared.anthropicApiKey = anthropicKey.isEmpty ? nil : anthropicKey
        SettingsStore.shared.todoistApiToken = todoistToken.isEmpty ? nil : todoistToken
        savedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedFeedback = false }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ClaudeMenue/Settings/SettingsView.swift
git commit -m "feat: SettingsView mit NSWindowController und Keychain-Speicherung"
```

---

## Task 12: ClaudeMenueApp.swift — Alles verbinden

**Files:**
- Create: `ClaudeMenue/App/ClaudeMenueApp.swift`

- [ ] **Step 1: ClaudeMenueApp.swift implementieren**

  Datei `ClaudeMenue/App/ClaudeMenueApp.swift`:
```swift
import SwiftUI

@main
struct ClaudeMenueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Leere Settings-Scene verhindert automatisches Fenster
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var hotKeyManager: HotKeyManager?
    private var windowController: InputWindowController?
    private var settingsWindowController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Kein Dock-Icon
        
        NotificationService.shared.requestPermission()
        
        settingsWindowController = SettingsWindowController.shared
        
        let windowCtrl = InputWindowController()
        self.windowController = windowCtrl
        
        let menuBar = MenuBarManager(windowController: windowCtrl)
        menuBar.settingsWindowController = settingsWindowController
        menuBar.setup()
        self.menuBarManager = menuBar
        
        // Hotkey ⌘⇧Space
        let hotKey = HotKeyManager()
        hotKey.onHotKey = { [weak windowCtrl] in
            windowCtrl?.showCentered()
        }
        hotKey.start()
        self.hotKeyManager = hotKey
        
        // Services aufbauen (wenn Keys vorhanden)
        rebuildServices()
        
        // Wenn noch nicht konfiguriert → Einstellungen öffnen
        if !SettingsStore.shared.isConfigured {
            settingsWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func rebuildServices() {
        guard let apiKey = SettingsStore.shared.anthropicApiKey,
              let todoistToken = SettingsStore.shared.todoistApiToken else { return }
        
        let todoistService = TodoistService(token: todoistToken)
        let claudeService = ClaudeService(apiKey: apiKey, todoistService: todoistService)
        
        windowController?.onSubmit = { [weak self, weak claudeService] text in
            guard let claudeService else { return }
            await claudeService.process(input: text) { [weak self] loading in
                self?.menuBarManager?.setLoading(loading)
            }
        }
    }
}
```

- [ ] **Step 2: Alle Tests ausführen — müssen PASS sein**

  ⌘U. Erwartet: alle Tests grün (keine Regressionen).

- [ ] **Step 3: App bauen und manuell testen**

  ⌘B um zu bauen. Dann ⌘R um zu starten:
  - Menüleisten-Icon erscheint rechts oben ✓
  - Linksklick öffnet Eingabefenster in Bildschirmmitte ✓
  - ⌘⇧Space öffnet Fenster (nach Accessibility-Erlaubnis) ✓
  - Rechtsklick zeigt Menü mit "Einstellungen" und "Beenden" ✓
  - Ohne konfigurierte Keys öffnet sich Einstellungsfenster automatisch ✓

- [ ] **Step 4: API Keys in Einstellungen eintragen und End-to-End testen**

  - Einstellungen öffnen, Anthropic API Key und Todoist Token eintragen, Speichern
  - App neu starten
  - Im Eingabefenster: *"Erinnere mich morgen: Zahnarzt anrufen"* → ⌘↩
  - Erwartung: Todoist-Task wird angelegt, Notification "Todoist-Task erstellt" erscheint ✓
  - Im Eingabefenster: *"Notiz: Idee für Wärmepumpe Optimierung"* → ⌘↩
  - Erwartung: Obsidian-Notiz in 00_INBOX angelegt ✓

- [ ] **Step 5: App Bundle erstellen**

  In Xcode: Product → Archive → Distribute App → Copy App
  App-Bundle nach `/Applications/ClaudeMenue.app` kopieren.

- [ ] **Step 6: App zum Login hinzufügen**

  System-Einstellungen → Allgemein → Anmeldeobjekte → ClaudeMenue hinzufügen.

- [ ] **Step 7: Finaler Commit**

```bash
git add ClaudeMenue/App/ClaudeMenueApp.swift
git commit -m "feat: AppDelegate verdrahtet alle Komponenten, App startklar"
```

---

## Checkliste gegen Spec

| Spec-Anforderung | Task |
|---|---|
| macOS Menüleisten-App | Task 1, 10 |
| Schwebendes Eingabefenster, Bildschirmmitte | Task 9 |
| Markdown-fähiges Textfeld | Task 8 |
| ⌘Return abschicken, Escape schließen | Task 8 |
| Claude entscheidet autonom (Function Calling) | Task 2, 7 |
| Todoist-Task anlegen | Task 6 |
| Obsidian-Notiz erstellen | Task 5 |
| Obsidian-Notiz aktualisieren (mit Fallback) | Task 5, 7 |
| macOS Notifications als Rückmeldung | Task 4 |
| Globale Tastenkombination ⌘⇧Space | Task 10 |
| API Keys sicher in Keychain | Task 3 |
| Einstellungsfenster | Task 11 |
| Ladeindikator im Menüleisten-Icon | Task 10, 12 |
| Fehlerbehandlung mit Notifications | Task 7 |
| Kein Dock-Icon | Task 1 (LSUIElement) |
