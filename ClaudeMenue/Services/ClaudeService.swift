import Foundation

class ClaudeService {
    private let session: URLSessionProtocol
    private let apiKey: String
    private let obsidianService: ObsidianService
    private let todoistService: TodoistService
    private let notificationService: NotificationService

    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    // Customize this system prompt with your own name, projects, and known Obsidian filenames.
    // The more context you give Claude about your projects, the better it routes your thoughts.
    private let systemPrompt = """
    You are the personal assistant of [YOUR NAME].
    [YOUR NAME] sends you short thoughts, ideas, or tasks.
    You decide autonomously what to do with them and call the appropriate tools.
    Do NOT respond with text — only with tool calls.

    Projects of [YOUR NAME]:
    - Work: [Your work projects, e.g. "Acme Corp, Project Alpha"]
    - Personal: [Your personal projects, e.g. "Home renovation, Family history"]
    - Obsidian Vault: ~/path/to/your/obsidian/vault/
    - New notes always go in: 00_INBOX/
    - Known filenames for update_obsidian_note: [e.g. "home.md, finances.md, health.md"]
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

    @discardableResult
    func process(input: String, onLoadingChange: ((Bool) -> Void)? = nil) async -> String {
        onLoadingChange?(true)
        defer { onLoadingChange?(false) }

        do {
            let actions = try await fetchToolCalls(for: input)
            guard !actions.isEmpty else {
                return "Keine Aktion erkannt"
            }
            var results: [String] = []
            for action in actions {
                let result = try await execute(action: action)
                results.append(result)
            }
            return results.joined(separator: "\n")
        } catch {
            return "Fehler: \(error.localizedDescription)"
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

    private func execute(action: ToolCallAction) async throws -> String {
        switch action {
        case .createTodoistTask(let title, let description, let project, let dueDate):
            try await todoistService.createTask(title: title, description: description, project: project, dueDate: dueDate)
            notificationService.send(title: "✓ Todoist-Task erstellt", body: title)
            return "✓ Task: \(title)"

        case .createObsidianNote(let filename, let content, let folder):
            try obsidianService.createNote(filename: filename, content: content, folder: folder ?? "00_INBOX")
            notificationService.send(title: "✓ Obsidian-Notiz erstellt", body: filename)
            return "✓ Notiz: \(filename)"

        case .updateObsidianNote(let filename, let contentToAppend):
            do {
                try obsidianService.updateNote(filename: filename, contentToAppend: contentToAppend)
                notificationService.send(title: "✓ Obsidian-Notiz aktualisiert", body: filename)
                return "✓ Notiz aktualisiert: \(filename)"
            } catch ObsidianService.ObsidianError.fileNotFound {
                try obsidianService.createNote(filename: filename, content: contentToAppend)
                notificationService.send(title: "✓ Obsidian-Notiz erstellt", body: filename)
                return "✓ Notiz erstellt: \(filename)"
            }
        }
    }

    enum ClaudeError: LocalizedError {
        case apiError
        var errorDescription: String? { "Fehler beim Senden an Claude" }
    }
}
