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
