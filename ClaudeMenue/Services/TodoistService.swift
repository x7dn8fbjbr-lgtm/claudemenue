import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

class TodoistService {
    private let session: URLSessionProtocol
    private let baseURL = URL(string: "https://api.todoist.com/api/v1")!
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
        if let project = project, !project.isEmpty { body["project_id"] = project }

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
