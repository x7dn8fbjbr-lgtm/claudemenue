import XCTest
@testable import ClaudeMenue

final class AnthropicModelsTests: XCTestCase {

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

    func test_contentBlock_unknownToolReturnsNil() throws {
        let json = """
        { "type": "tool_use", "id": "t3", "name": "unknown_tool", "input": {} }
        """.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        XCTAssertNil(block.toToolCallAction())
    }

    func test_contentBlock_parsesToUpdateObsidianNote() throws {
        let json = """
        {
            "type": "tool_use",
            "id": "t4",
            "name": "update_obsidian_note",
            "input": { "filename": "waermepumpe-solar.md", "content_to_append": "Neue Messung: 4.2 COP" }
        }
        """.data(using: .utf8)!

        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .updateObsidianNote(let filename, let content) = block.toToolCallAction() else {
            XCTFail("Erwartet .updateObsidianNote")
            return
        }
        XCTAssertEqual(filename, "waermepumpe-solar.md")
        XCTAssertEqual(content, "Neue Messung: 4.2 COP")
    }
}
