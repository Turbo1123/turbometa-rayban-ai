/*
 * Conversation Record Model
 * 对话记录数据模型
 */

import Foundation

struct ConversationRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let messages: [ConversationMessage]
    let aiModel: String
    let language: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        messages: [ConversationMessage],
        aiModel: String = "qwen3-omni-flash-realtime",
        language: String = "zh-CN"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.messages = messages
        self.aiModel = aiModel
        self.language = language
    }

    // Computed properties
    var title: String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let content = firstUserMessage.content
            return content.count > 30 ? String(content.prefix(30)) + "..." : content
        }
        return "AI 对话"
    }

    var summary: String {
        if let lastMessage = messages.last {
            let content = lastMessage.content
            return content.count > 50 ? String(content.prefix(50)) + "..." : content
        }
        return ""
    }

    var messageCount: Int {
        return messages.count
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: timestamp)
        } else if calendar.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE HH:mm"
            return formatter.string(from: timestamp)
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }
}

// Make ConversationMessage Codable
extension ConversationMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let roleString = try container.decode(String.self, forKey: .role)
        let content = try container.decode(String.self, forKey: .content)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)

        self.init(
            id: id,
            role: roleString == "user" ? .user : .assistant,
            content: content,
            timestamp: timestamp
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role == .user ? "user" : "assistant", forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// Add timestamp to ConversationMessage if not present
extension ConversationMessage {
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.init(role: role, content: content)
    }
}
