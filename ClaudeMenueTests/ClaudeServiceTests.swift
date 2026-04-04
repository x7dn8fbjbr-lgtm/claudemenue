import XCTest
@testable import ClaudeMenue

final class ClaudeServiceTests: XCTestCase {

    func test_process_ruftTodoistBeiTaskAuf() async throws {
        let mockSession = MockURLSession()  // from TestHelpers.swift
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

// MARK: - Mocks (MockURLSession is in TestHelpers.swift)

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
