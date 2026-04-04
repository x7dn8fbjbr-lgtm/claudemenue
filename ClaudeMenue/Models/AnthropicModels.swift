import Foundation

// MARK: - Request

struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case tools
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
        case name
        case description
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

// MARK: - ContentBlock

struct ContentBlock: Decodable {
    let type: String
    let id: String?
    let name: String?
    let input: [String: JSONValue]?
    let text: String?
}

// MARK: - JSONValue

enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unbekannter JSON-Typ")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }
}
