import XCTest
@testable import ClaudeMenue

// MARK: - MockURLSession (shared by TodoistServiceTests + ClaudeServiceTests)

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
