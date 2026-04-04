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
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

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
